import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

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
  let staffId: string;
  try {
    const b = (await req.json()) as { staff_id?: string };
    staffId = String(b.staff_id ?? "").trim();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!staffId || staffId === invokerId) {
    return new Response(JSON.stringify({ error: "Invalid staff" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { data: me, error: meErr } = await admin
    .from("profiles")
    .select("tenant_id, role, permissions, staff_status")
    .eq("id", invokerId)
    .maybeSingle();

  if (meErr || !me?.tenant_id) {
    return new Response(JSON.stringify({ error: "Forbidden" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  const st = String(me.staff_status ?? "active").toLowerCase();
  if (st === "inactive") {
    return new Response(JSON.stringify({ error: "Inactive" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  const role = String(me.role ?? "").toLowerCase();
  const perms = me.permissions as Record<string, unknown> | null;
  const canManage = Boolean(perms?.["manage_staff"]);
  const allowed = ["pharmacy_owner", "pharmacist"].includes(role) || canManage;
  if (!allowed) {
    return new Response(JSON.stringify({ error: "Forbidden" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { data: target, error: tErr } = await admin
    .from("profiles")
    .select("tenant_id, role")
    .eq("id", staffId)
    .maybeSingle();

  if (tErr || !target?.tenant_id || target.tenant_id !== me.tenant_id) {
    return new Response(JSON.stringify({ error: "Forbidden" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (String(target.role) === "pharmacy_owner" && role !== "pharmacy_owner") {
    return new Response(JSON.stringify({ error: "Forbidden" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { error: dErr } = await admin.auth.admin.deleteUser(staffId);
  if (dErr) {
    return new Response(JSON.stringify({ error: dErr.message }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
