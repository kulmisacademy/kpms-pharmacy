import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import {
  normalizeEmail,
  randomChallengeToken,
  sha256Hex,
  timingSafeEqualHex,
} from "../_shared/password_reset_crypto.ts";
import { jsonResponse } from "../_shared/password_reset_response.ts";

const LOG = "kpms.verify-password-reset-otp";
const MAX_VERIFY_ATTEMPTS = 5;
const CHALLENGE_TTL_MIN = 15;

async function handleRequest(req: Request): Promise<Response> {
  if (req.method !== "POST") {
    return jsonResponse(405, { error: "method_not_allowed" });
  }

  const pepper = Deno.env.get("PASSWORD_RESET_PEPPER");
  if (!pepper || pepper.length < 16) {
    console.error(`[${LOG}] pepper_missing_or_short`);
    return jsonResponse(503, { error: "service_unavailable" });
  }

  let body: { email?: string; code?: string };
  try {
    body = (await req.json()) as { email?: string; code?: string };
  } catch {
    return jsonResponse(400, { error: "invalid_json" });
  }

  const email = normalizeEmail((body.email ?? "").trim());
  const code = (body.code ?? "").replace(/\D/g, "").trim();
  if (!email.includes("@") || code.length !== 6) {
    return jsonResponse(400, { error: "invalid_input" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) {
    console.error(`[${LOG}] missing_supabase_env`);
    return jsonResponse(503, { error: "service_unavailable" });
  }

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  console.log(`[${LOG}] lookup_otp`);

  const { data: rows, error: qErr } = await admin
    .from("password_reset_otps")
    .select("id, otp_hash, expires_at, used, verify_attempts")
    .eq("email", email)
    .eq("used", false)
    .order("created_at", { ascending: false })
    .limit(1);

  if (qErr) {
    console.error(`[${LOG}] otp_select`, { code: qErr.code, message: qErr.message });
    return jsonResponse(503, { error: "otp_storage_failed" });
  }
  if (!rows?.length) {
    return jsonResponse(401, { error: "invalid_code" });
  }

  const row = rows[0] as {
    id: string;
    otp_hash: string;
    expires_at: string;
    used: boolean;
    verify_attempts: number;
  };

  const expires = new Date(row.expires_at).getTime();
  if (Date.now() > expires) {
    await admin.from("password_reset_otps").update({ used: true }).eq(
      "id",
      row.id,
    );
    return jsonResponse(401, { error: "expired_code" });
  }

  if (row.verify_attempts >= MAX_VERIFY_ATTEMPTS) {
    return jsonResponse(429, { error: "verify_locked" });
  }

  const expected = await sha256Hex(`otp:v2:${email}:${code}:${pepper}`);
  if (!timingSafeEqualHex(expected, row.otp_hash)) {
    const next = row.verify_attempts + 1;
    await admin.from("password_reset_otps").update({
      verify_attempts: next,
    }).eq("id", row.id);
    if (next >= MAX_VERIFY_ATTEMPTS) {
      return jsonResponse(429, { error: "verify_locked" });
    }
    return jsonResponse(401, { error: "invalid_code" });
  }

  await admin.from("password_reset_otps").update({ used: true }).eq(
    "id",
    row.id,
  );

  await admin.from("password_reset_challenges").update({ used: true }).eq(
    "email",
    email,
  ).eq("used", false);

  const plain = randomChallengeToken();
  const tokenHash = await sha256Hex(`ch:v2:${email}:${plain}:${pepper}`);
  const chExp = new Date(
    Date.now() + CHALLENGE_TTL_MIN * 60_000,
  ).toISOString();

  console.log(`[${LOG}] insert_challenge`);

  const { error: chErr } = await admin.from("password_reset_challenges").insert({
    email,
    token_hash: tokenHash,
    expires_at: chExp,
    used: false,
  });
  if (chErr) {
    console.error(`[${LOG}] challenge_insert`, { code: chErr.code, message: chErr.message });
    return jsonResponse(503, { error: "challenge_storage_failed" });
  }

  console.log(`[${LOG}] ok`);
  return jsonResponse(200, { ok: true, challenge_token: plain });
}

serve(async (req) => {
  try {
    return await handleRequest(req);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error(`[${LOG}] unhandled`, { err: msg.slice(0, 400) });
    return jsonResponse(503, { error: "service_unavailable" });
  }
});
