import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import {
  normalizeEmail,
  sha256Hex,
} from "../_shared/password_reset_crypto.ts";
import { jsonResponse } from "../_shared/password_reset_response.ts";

const LOG = "kpms.complete-password-reset";

/** Align with Flutter `KpmsPasswordPolicy.meetsPharmacySignupRules` (minimum length only). */
function passwordMeetsPolicy(p: string): boolean {
  return p.length >= 8;
}

async function handleRequest(req: Request): Promise<Response> {
  if (req.method !== "POST") {
    return jsonResponse(405, { error: "method_not_allowed" });
  }

  const pepper = Deno.env.get("PASSWORD_RESET_PEPPER");
  if (!pepper || pepper.length < 16) {
    console.error(`[${LOG}] pepper_missing_or_short`);
    return jsonResponse(503, { error: "service_unavailable" });
  }

  let body: { email?: string; challenge_token?: string; password?: string };
  try {
    body = (await req.json()) as {
      email?: string;
      challenge_token?: string;
      password?: string;
    };
  } catch {
    return jsonResponse(400, { error: "invalid_json" });
  }

  const email = normalizeEmail((body.email ?? "").trim());
  const plain = (body.challenge_token ?? "").trim();
  const password = body.password ?? "";
  if (!email.includes("@") || plain.length < 32) {
    return jsonResponse(400, { error: "invalid_input" });
  }
  if (!passwordMeetsPolicy(password)) {
    return jsonResponse(400, { error: "password_policy_failed" });
  }

  const tokenHash = await sha256Hex(`ch:v2:${email}:${plain}:${pepper}`);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) {
    console.error(`[${LOG}] missing_supabase_env`);
    return jsonResponse(503, { error: "service_unavailable" });
  }

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  console.log(`[${LOG}] lookup_challenge`);

  const { data: rows, error: qErr } = await admin
    .from("password_reset_challenges")
    .select("id, expires_at, used")
    .eq("email", email)
    .eq("token_hash", tokenHash)
    .eq("used", false)
    .limit(1);

  if (qErr) {
    console.error(`[${LOG}] challenge_select`, { code: qErr.code, message: qErr.message });
    return jsonResponse(503, { error: "challenge_storage_failed" });
  }
  if (!rows?.length) {
    return jsonResponse(401, { error: "invalid_or_expired_challenge" });
  }

  const ch = rows[0] as { id: string; expires_at: string; used: boolean };
  if (Date.now() > new Date(ch.expires_at).getTime()) {
    await admin.from("password_reset_challenges").update({ used: true }).eq(
      "id",
      ch.id,
    );
    return jsonResponse(401, { error: "invalid_or_expired_challenge" });
  }

  const { data: userId, error: uidErr } = await admin.rpc(
    "kpms_auth_user_id_by_email",
    { p_email: email },
  );
  if (uidErr) {
    console.error(`[${LOG}] rpc_user_lookup`, { code: uidErr.code, message: uidErr.message });
    return jsonResponse(503, { error: "user_lookup_failed" });
  }
  if (!userId) {
    return jsonResponse(503, { error: "user_lookup_failed" });
  }

  const uid = userId as string;

  console.log(`[${LOG}] auth_update_password`);

  const { error: upErr } = await admin.auth.admin.updateUserById(
    uid,
    { password },
  );
  if (upErr) {
    console.error(`[${LOG}] auth_update_failed`, { message: upErr.message });
    return jsonResponse(400, { error: "password_update_failed" });
  }

  const { error: revErr } = await admin.rpc(
    "kpms_revoke_auth_user_refresh_tokens",
    { p_user_id: uid },
  );
  if (revErr) {
    console.error(`[${LOG}] revoke_sessions`, { code: revErr.code, message: revErr.message });
  }

  const { error: audErr } = await admin.from("password_reset_audit").insert({
    email,
    event: "password_reset_complete",
    meta: {},
  });
  if (audErr) {
    console.error(`[${LOG}] audit_insert`, { code: audErr.code, message: audErr.message });
  }

  await admin.from("password_reset_challenges").update({ used: true }).eq(
    "id",
    ch.id,
  );

  await admin.from("password_reset_otps").update({ used: true }).eq(
    "email",
    email,
  ).eq("used", false);

  console.log(`[${LOG}] ok`);
  return jsonResponse(200, { ok: true });
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
