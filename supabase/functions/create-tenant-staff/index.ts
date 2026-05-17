import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

type Body = {
  email: string;
  password: string;
  full_name: string;
  phone?: string;
  role: string;
  permissions: Record<string, unknown>;
};

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const authHeader = req.headers.get("Authorization") ?? "";

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const jwt = authHeader.replace(/^Bearer\s+/i, "");
  const { data: invoker, error: invErr } = await admin.auth.getUser(jwt);
  if (invErr || !invoker.user) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const invokerId = invoker.user.id;
  const { data: profile, error: pErr } = await admin
    .from("profiles")
    .select("tenant_id, role, permissions, staff_status")
    .eq("id", invokerId)
    .maybeSingle();

  if (pErr || !profile?.tenant_id) {
    return new Response(JSON.stringify({ error: "Forbidden" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  const st = String(profile.staff_status ?? "active").toLowerCase();
  if (st === "inactive") {
    return new Response(JSON.stringify({ error: "Inactive" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  const role = String(profile.role ?? "").toLowerCase();
  const perms = profile.permissions as Record<string, unknown> | null;
  const canManage = Boolean(perms?.["manage_staff"]);
  const allowed = ["pharmacy_owner", "pharmacist", "pharmacy_admin"].includes(role) || canManage;
  if (!allowed) {
    return new Response(JSON.stringify({ error: "Forbidden" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  let body: Body;
  try {
    body = (await req.json()) as Body;
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const email = String(body.email ?? "").trim().toLowerCase();
  const password = String(body.password ?? "");
  const fullName = String(body.full_name ?? "").trim();
  const phone = String(body.phone ?? "").trim();
  const staffRole = String(body.role ?? "staff").trim().toLowerCase();
  const permissions = body.permissions ?? {};

  if (!email || !password || password.length < 8) {
    return new Response(JSON.stringify({ error: "Email and password (min 8 chars) required" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!["staff", "cashier", "pharmacist", "manager", "pharmacy_admin", "accountant", "inventory_manager", "clinical_pharmacist"].includes(staffRole)) {
    return new Response(JSON.stringify({ error: "Invalid role" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { data: created, error: cErr } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name: fullName },
  });

  if (cErr || !created.user) {
    return new Response(JSON.stringify({ error: cErr?.message ?? "Create user failed" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const uid = created.user.id;

  const { error: uErr } = await admin.from("profiles").update({
    tenant_id: profile.tenant_id,
    role: staffRole,
    permissions,
    full_name: fullName || null,
    phone: phone || null,
    staff_status: "active",
    account_email: email,
    created_by: invokerId,
    updated_at: new Date().toISOString(),
  }).eq("id", uid);

  if (uErr) {
    await admin.auth.admin.deleteUser(uid);
    return new Response(JSON.stringify({ error: uErr.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ user_id: uid }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
