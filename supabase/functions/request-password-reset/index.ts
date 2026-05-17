import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { SMTPClient } from "https://deno.land/x/denomailer@1.6.0/mod.ts";
import {
  normalizeEmail,
  randomOtp6,
  sha256Hex,
} from "../_shared/password_reset_crypto.ts";
import { jsonResponse } from "../_shared/password_reset_response.ts";

const LOG = "kpms.request-password-reset";
const OTP_TTL_MIN = 10;
const MAX_REQUESTS_PER_HOUR = 5;

function smtpPort(): number {
  const raw = Deno.env.get("SMTP_PORT")?.trim();
  if (!raw) return 587;
  const n = Number(raw);
  return Number.isFinite(n) && n > 0 && n < 65536 ? n : 587;
}

async function sendResetEmail(to: string, code: string) {
  const host = (Deno.env.get("SMTP_HOST") ?? "smtp.gmail.com").trim();
  const port = smtpPort();
  const user = Deno.env.get("SMTP_USER")?.trim();
  const pass = Deno.env.get("SMTP_PASS");
  const from = Deno.env.get("EMAIL_FROM")?.trim() ??
    `KPMS <${user ?? "noreply"}>`;
  if (!user || !pass) {
    console.error(`[${LOG}] smtp_missing_env`, { hasUser: !!user, hasPass: !!pass });
    throw new Error("smtp_not_configured");
  }

  console.log(`[${LOG}] smtp_connect`, { host, port, implicitTls: port === 465 });

  const useImplicitTls = port === 465;
  const client = new SMTPClient({
    connection: {
      hostname: host,
      port,
      tls: useImplicitTls,
      auth: { username: user, password: pass },
    },
  });

  const subject = "KPMS — Your password reset code";
  const safeCode = code.replace(/\D/g, "");
  const logoSvg =
    `<svg xmlns="http://www.w3.org/2000/svg" width="200" height="52" viewBox="0 0 200 52">` +
    `<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ecfdf5"/>` +
    `<stop offset="1" stop-color="#bbf7d0"/></linearGradient></defs>` +
    `<rect x="8" y="8" width="36" height="36" rx="10" fill="rgba(255,255,255,0.22)"/>` +
    `<path d="M22 34V18l8 10 8-10v16" fill="none" stroke="url(#g)" stroke-width="2.2" stroke-linecap="round"/>` +
    `<text x="118" y="34" text-anchor="middle" fill="url(#g)" font-family="system-ui,Segoe UI,sans-serif" ` +
    `font-weight="800" font-size="20" letter-spacing="0.06em">KPMS</text></svg>`;
  const logoSrc = `data:image/svg+xml;charset=utf-8,${encodeURIComponent(logoSvg)}`;
  const html = `
<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>Password reset</title></head>
<body style="margin:0;background:#0f172a;font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:linear-gradient(160deg,#0f172a 0%,#134e4a 55%,#0f172a 100%);padding:32px 16px;">
    <tr><td align="center">
      <table role="presentation" width="100%" style="max-width:520px;background:#ffffff;border-radius:20px;overflow:hidden;box-shadow:0 24px 48px rgba(0,0,0,.35);">
        <tr><td style="background:linear-gradient(90deg,#0d9488,#15803d);padding:24px 28px;text-align:center;">
          <img src="${logoSrc}" width="180" height="48" alt="KPMS" style="display:block;margin:0 auto 12px;max-width:100%;height:auto;"/>
          <div style="color:#d1fae5;font-size:13px;line-height:1.45;opacity:0.95;">KULMIS Pharmacy · ERP / POS</div>
        </td></tr>
        <tr><td style="padding:28px 28px 8px;">
          <h1 style="margin:0 0 8px;font-size:22px;color:#0f172a;">Password reset</h1>
          <p style="margin:0;color:#475569;font-size:15px;line-height:1.55;">Use this one-time code in the KPMS app to finish resetting your password. Do not share this code.</p>
        </td></tr>
        <tr><td style="padding:8px 28px 28px;text-align:center;">
          <div style="display:inline-block;padding:18px 28px;border-radius:16px;background:#f0fdf4;border:2px solid #86efac;">
            <div style="font-size:11px;font-weight:700;color:#166534;letter-spacing:.12em;text-transform:uppercase;">Verification code</div>
            <div style="font-size:34px;font-weight:800;letter-spacing:10px;color:#14532d;margin-top:8px;font-variant-numeric:tabular-nums;">${safeCode}</div>
          </div>
          <p style="margin:22px 0 0;font-size:14px;color:#64748b;">This code expires in <strong style="color:#0f172a;">${OTP_TTL_MIN} minutes</strong>.</p>
          <p style="margin:12px 0 0;font-size:14px;color:#64748b;">If you did not request this reset, you can ignore this email. Your password will stay the same.</p>
        </td></tr>
        <tr><td style="padding:0 28px 24px;">
          <hr style="border:none;border-top:1px solid #e2e8f0;margin:0;"/>
          <p style="margin:16px 0 0;font-size:12px;color:#94a3b8;line-height:1.5;">Security: KPMS staff will never ask for this code. Never forward this email.</p>
        </td></tr>
      </table>
      <p style="margin:20px 0 0;font-size:11px;color:#94a3b8;">© KULMIS KPMS</p>
    </td></tr>
  </table>
</body></html>`;

  try {
    await client.send({
      from,
      to,
      subject,
      content: `Your KPMS password reset code is ${safeCode}. It expires in ${OTP_TTL_MIN} minutes.`,
      html,
    });
    console.log(`[${LOG}] smtp_send_ok`, { toDomain: to.includes("@") ? to.split("@")[1] : "?" });
  } finally {
    await client.close();
  }
}

function classifySmtpFailure(message: string): "smtp_auth_failed" | "email_send_failed" {
  const m = message.toLowerCase();
  if (
    /535|534|538|auth|credential|password|invalid login|not accepted|username and password/.test(
      m,
    )
  ) {
    return "smtp_auth_failed";
  }
  return "email_send_failed";
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

  let body: { email?: string };
  try {
    body = (await req.json()) as { email?: string };
  } catch {
    return jsonResponse(400, { error: "invalid_json" });
  }

  const raw = (body.email ?? "").trim();
  const email = normalizeEmail(raw);
  if (!email.includes("@") || email.length > 254) {
    return jsonResponse(400, { error: "invalid_email" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) {
    console.error(`[${LOG}] missing_supabase_env`, {
      hasUrl: !!supabaseUrl,
      hasServiceKey: !!serviceKey,
    });
    return jsonResponse(503, { error: "service_unavailable" });
  }

  console.log(`[${LOG}] start`, { emailLen: email.length });

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: userId, error: uidErr } = await admin.rpc(
    "kpms_auth_user_id_by_email",
    { p_email: email },
  );
  if (uidErr) {
    console.error(`[${LOG}] rpc_user_lookup`, { code: uidErr.code, message: uidErr.message });
    return jsonResponse(503, { error: "user_lookup_failed" });
  }

  const expiresAt = new Date(Date.now() + OTP_TTL_MIN * 60_000).toISOString();

  if (!userId) {
    console.log(`[${LOG}] no_user_anti_enum`);
    return jsonResponse(200, { ok: true, expires_at: expiresAt });
  }

  console.log(`[${LOG}] user_found`);

  const since = new Date(Date.now() - 60 * 60_000).toISOString();
  const { count, error: cErr } = await admin
    .from("password_reset_otps")
    .select("id", { count: "exact", head: true })
    .eq("email", email)
    .gte("created_at", since);
  if (cErr) {
    console.error(`[${LOG}] rate_count_query`, { code: cErr.code, message: cErr.message });
    return jsonResponse(503, { error: "otp_storage_failed" });
  }
  if ((count ?? 0) >= MAX_REQUESTS_PER_HOUR) {
    console.log(`[${LOG}] rate_limited`, { count });
    return jsonResponse(429, { error: "rate_limited" });
  }

  await admin.from("password_reset_otps").update({ used: true }).eq(
    "email",
    email,
  ).eq("used", false);

  const code = randomOtp6();
  const otpHash = await sha256Hex(`otp:v2:${email}:${code}:${pepper}`);

  console.log(`[${LOG}] otp_generated`);

  const { error: insErr } = await admin.from("password_reset_otps").insert({
    email,
    otp_hash: otpHash,
    expires_at: expiresAt,
    used: false,
    verify_attempts: 0,
  });
  if (insErr) {
    console.error(`[${LOG}] otp_insert`, { code: insErr.code, message: insErr.message });
    return jsonResponse(503, { error: "otp_storage_failed" });
  }

  console.log(`[${LOG}] otp_insert_ok`);

  try {
    await sendResetEmail(raw.trim() || email, code);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    const safe = msg.slice(0, 280);
    console.error(`[${LOG}] smtp_send_failed`, { err: safe });
    const errCode = classifySmtpFailure(msg);
    return jsonResponse(503, { error: errCode });
  }

  console.log(`[${LOG}] done`);
  return jsonResponse(200, { ok: true, expires_at: expiresAt });
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
