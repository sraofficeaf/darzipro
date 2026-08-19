// approve-registration Edge Function
// Called by AdminService.approveRegistration() in the Flutter app.
// This function:
//   1. Verifies the caller has a real Supabase Auth session (JWT from signInWithPassword)
//   2. Confirms the caller's email exists in admin_users (server-side check, not client-supplied)
//   3. Uses service_role key INTERNALLY (server-side only, never sent to client) to:
//      - Create the new customer's auth.users account
//      - Create their shop, profile, license records
//      - Approve the public_registrations row
//      - Trigger multi-level profit calculations

/// <reference path="../deno.d.ts" />
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // ─── STEP 1: Verify caller has a real Supabase Auth session ───────────
    const authHeader = req.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return new Response(JSON.stringify({ success: false, error: "Unauthorized: No auth token" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const callerJwt = authHeader.replace("Bearer ", "");

    // Create a caller-scoped client to verify their identity via JWT
    const callerClient = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${callerJwt}` } },
    });
    const { data: { user: callerUser }, error: authError } = await callerClient.auth.getUser();
    if (authError || !callerUser) {
      return new Response(JSON.stringify({ success: false, error: "Unauthorized: Invalid session" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ─── STEP 2: Confirm caller is in admin_users ──────────────────────────
    // Use service_role client for this check so RLS on admin_users doesn't block it
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const { data: adminRow, error: adminErr } = await adminClient
      .from("admin_users")
      .select("id, email, role")
      .eq("email", callerUser.email!)
      .maybeSingle();

    if (adminErr || !adminRow) {
      return new Response(JSON.stringify({ success: false, error: "Forbidden: Not an admin" }), {
        status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ─── STEP 3: Parse request body ───────────────────────────────────────
    const body = await req.json();
    const {
      id,           // public_registrations row id
      shopName,
      ownerName,
      email,
      plan,
      password,
      inviteCodeUsed,
    } = body;

    if (!id || !shopName || !ownerName || !email || !plan) {
      return new Response(JSON.stringify({ success: false, error: "Missing required fields" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Fetch the registration row for phone, address, and admin notes
    const { data: regRow } = await adminClient
      .from("public_registrations")
      .select("admin_notes, phone, address")
      .eq("id", id)
      .maybeSingle();

    // ─── STEP 4: Determine password ───────────────────────────────────────
    let userPassword = password || "";
    if (!userPassword) {
      if (regRow?.admin_notes && regRow.admin_notes.length >= 6) userPassword = regRow.admin_notes;
    }
    if (!userPassword || userPassword.length < 6) {
      userPassword = generateTempPassword();
    }

    // ─── STEP 5: Create auth.users account (SERVICE ROLE, server-side) ────
    let userId: string | null = null;
    const { data: authUser, error: createErr } = await adminClient.auth.admin.createUser({
      email,
      password: userPassword,
      email_confirm: true,
    });

    if (createErr) {
      // User may already exist — find by email
      const { data: listData } = await adminClient.auth.admin.listUsers();
      const existing = listData?.users?.find(
        (u: any) => u.email?.toLowerCase() === email.toLowerCase()
      );
      if (existing) {
        userId = existing.id;
        // Update password and confirm
        await adminClient.auth.admin.updateUserById(userId, {
          password: userPassword,
          email_confirm: true,
        });
      } else {
        return new Response(JSON.stringify({ success: false, error: `Auth user creation failed: ${createErr.message}` }), {
          status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    } else {
      userId = authUser.user?.id ?? null;
    }

    if (!userId) {
      return new Response(JSON.stringify({ success: false, error: "Failed to obtain user ID" }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ─── STEP 6: Determine invite level ───────────────────────────────────
    const inviteCode = generateInviteCode();
    let inviteLevelUnlocked = 1;
    if (plan === "full_access") inviteLevelUnlocked = 2;
    else if (plan === "full_access_3yr") inviteLevelUnlocked = 4;

    // ─── STEP 7: Create shop ──────────────────────────────────────────────
    const shopPayload: Record<string, any> = {
      name: shopName,
      currency: "PKR",
      invite_code: inviteCode,
      invite_level_unlocked: inviteLevelUnlocked,
      phone: regRow?.phone || null,
      address: regRow?.address || null,
    };
    if (plan === "full_access_3yr") {
      shopPayload.bundled_storage_expires_at = new Date(
        Date.now() + 3 * 365 * 24 * 60 * 60 * 1000
      ).toISOString();
    }
    if (inviteCodeUsed) shopPayload.invited_by_code = inviteCodeUsed;

    const { data: shopRows, error: shopErr } = await adminClient
      .from("shops")
      .insert(shopPayload)
      .select();

    if (shopErr || !shopRows || shopRows.length === 0) {
      return new Response(JSON.stringify({ success: false, error: `Shop creation failed: ${shopErr?.message}` }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const shopId = shopRows[0].id as string;

    // ─── STEP 8: Create profile ───────────────────────────────────────────
    const { error: profErr } = await adminClient.from("profiles").insert({
      id: userId,
      shop_id: shopId,
      full_name: ownerName,
      role: "owner",
    });

    if (profErr) {
      return new Response(JSON.stringify({ success: false, error: `Profile creation failed: ${profErr.message}` }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ─── STEP 9: Create license ───────────────────────────────────────────
    const expiryDate = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
    const { error: licErr } = await adminClient.from("licenses").insert({
      shop_id: shopId,
      license_key: `DARZI-${generateCode(4)}-${generateCode(4)}-${generateCode(4)}`,
      shop_name: shopName,
      email: email,
      phone: regRow?.phone || null,
      plan,
      status: "active",
      expires_at: expiryDate,
      notes: "Approved via admin panel (Registration)",
    });

    if (licErr) {
      return new Response(JSON.stringify({ success: false, error: `License creation failed: ${licErr.message}` }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ─── STEP 10: Multi-level profit calculation ──────────────────────────
    if (inviteCodeUsed) {
      let amount = 35000;
      let earningType = "signup_full_access";
      if (plan === "mobile_only") { amount = 12000; earningType = "signup_mobile_only"; }
      else if (plan === "full_access_3yr") { amount = 70000; earningType = "signup_full_access_3yr"; }
      await calculateMultilevelProfit(adminClient, shopId, amount, earningType);
    }

    // ─── STEP 11: Update registration status ─────────────────────────────
    await adminClient.from("public_registrations").update({
      status: "approved",
      created_shop_id: shopId,
      reviewed_at: new Date().toISOString(),
      reviewed_by: adminRow.id,
    }).eq("id", id);

    return new Response(JSON.stringify({
      success: true,
      tempPassword: userPassword,
      shopId,
      userId,
    }), { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });

  } catch (err: any) {
    console.error("approve-registration error:", err);
    return new Response(JSON.stringify({ success: false, error: err.message ?? "Unknown error" }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

// ── Helpers ──────────────────────────────────────────────────────────────────

function generateInviteCode(): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let code = "";
  for (let i = 0; i < 8; i++) code += chars[Math.floor(Math.random() * chars.length)];
  return code;
}

function generateCode(len: number): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ0123456789";
  let s = "";
  for (let i = 0; i < len; i++) s += chars[Math.floor(Math.random() * chars.length)];
  return s;
}

function generateTempPassword(): string {
  return "Darzi@" + Math.floor(100000 + Math.random() * 900000);
}

async function calculateMultilevelProfit(
  client: any,
  payingShopId: string,
  amount: number,
  earningType: string
) {
  const levelPercentages = [0.15, 0.025, 0.015, 0.01];
  let currentShopId: string | null = payingShopId;

  const { data: platformSetting } = await client
    .from("app_settings")
    .select("value")
    .eq("key", "platform_owner_shop_id")
    .maybeSingle();
  const platformOwnerId = platformSetting?.value as string | undefined;

  for (let level = 0; level < 4; level++) {
    const { data: currentShopData } = await client
      .from("shops")
      .select("invited_by_code")
      .eq("id", currentShopId)
      .maybeSingle();
    if (!currentShopData?.invited_by_code) break;

    const inviterCode = currentShopData.invited_by_code;
    const { data: inviterShopData } = await client
      .from("shops")
      .select("id, invite_level_unlocked, status")
      .eq("invite_code", inviterCode)
      .maybeSingle();
    if (!inviterShopData) break;

    let inviterShopId = inviterShopData.id as string;
    if (inviterShopData.status === "deleted" && platformOwnerId) {
      inviterShopId = platformOwnerId;
    }
    const inviteLevelUnlocked = (inviterShopData.invite_level_unlocked as number) ?? 1;

    if (inviteLevelUnlocked >= level + 1) {
      const earning = Math.round(amount * levelPercentages[level]);
      await client.from("profit_earnings").insert({
        inviter_shop_id: inviterShopId,
        invited_shop_id: payingShopId,
        earning_type: earningType,
        amount: earning,
        level: level + 1,
        status: "pending",
        created_at: new Date().toISOString(),
      });
    }

    currentShopId = inviterShopId === platformOwnerId ? null : inviterShopId;
    if (!currentShopId) break;
  }
}
