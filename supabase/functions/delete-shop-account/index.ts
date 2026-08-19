// Supabase Edge Function: delete-shop-account
// Deno runtime — TypeScript
// 
// FLOW:
//   Step 0  — Idempotency guard (check if already deleted)
//   Step 0.5 — Verify caller owns this shop_id
//   Step 1-7 — Call perform_shop_deletion() RPC (single atomic transaction)
//   Step 8  — Delete storage files
//   Step 9  — Ban auth user (NOT hard-delete, to preserve anonymized shops row)

/// <reference path="../deno.d.ts" />
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // ── Create admin client (service role — needed for auth.admin operations)
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    // ── Create user client (anon with caller's JWT — for identity verification)
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: No authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseUser = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    );

    // ── Verify caller's identity
    const { data: { user }, error: authError } = await supabaseUser.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized: Invalid session" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── Parse request body safely
    let shop_id: string | null = null;
    try {
      const body = await req.json();
      shop_id = body?.shop_id ?? null;
    } catch (_) {
      shop_id = null;
    }

    if (!shop_id) {
      return new Response(
        JSON.stringify({ error: "Missing shop_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── SECURITY: Verify caller owns this shop_id
    const { data: profileData, error: profileError } = await supabaseAdmin
      .from("profiles")
      .select("shop_id, id")
      .eq("id", user.id)
      .maybeSingle();

    if (profileError || !profileData || profileData.shop_id !== shop_id) {
      return new Response(
        JSON.stringify({ error: "Forbidden: You do not own this shop" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── STEP 0: Idempotency Guard
    // If shop already deleted, return success immediately (safe retry)
    const { data: shopData } = await supabaseAdmin
      .from("shops")
      .select("status, logo_url, name")
      .eq("id", shop_id)
      .maybeSingle();

    if (shopData?.status === "deleted") {
      console.log(`Shop ${shop_id} already deleted — returning success (idempotent)`);
      return new Response(
        JSON.stringify({ success: true, message: "Account already deleted" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const shopLogoUrl = shopData?.logo_url as string | null;

    // ── Collect order image storage paths BEFORE deletion
    const { data: orderImages } = await supabaseAdmin
      .from("order_images")
      .select("storage_path")
      .eq("shop_id", shop_id);

    const imageStoragePaths: string[] = (orderImages ?? [])
      .map((img: { storage_path: string }) => img.storage_path)
      .filter(Boolean);

    // ── STEPS 1-7: Atomic transaction via Postgres RPC
    // perform_shop_deletion() runs everything in a single DB transaction.
    // If anything fails inside, it rolls back completely — shop stays active.
    const { error: rpcError } = await supabaseAdmin.rpc("perform_shop_deletion", {
      p_shop_id: shop_id,
    });

    if (rpcError) {
      console.error("Deletion RPC failed:", rpcError);
      return new Response(
        JSON.stringify({
          error: "Deletion failed — no changes were made",
          details: rpcError.message,
        }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── STEP 8: Delete storage files (outside transaction — best effort)
    // This runs AFTER the DB transaction commits successfully.
    // If storage deletion fails, DB is still correctly anonymized.
    try {
      // Delete shop logo
      if (shopLogoUrl) {
        // Extract path from full URL: .../storage/v1/object/public/shop-logos/<path>
        const logoPath = shopLogoUrl.includes("shop-logos/")
          ? shopLogoUrl.split("shop-logos/")[1]
          : null;
        if (logoPath) {
          await supabaseAdmin.storage.from("shop-logos").remove([logoPath]);
          console.log(`Deleted logo: ${logoPath}`);
        }
      }

      // Delete order design images from design-images bucket
      if (imageStoragePaths.length > 0) {
        const chunks: string[][] = [];
        for (let i = 0; i < imageStoragePaths.length; i += 100) {
          chunks.push(imageStoragePaths.slice(i, i + 100));
        }
        for (const chunk of chunks) {
          await supabaseAdmin.storage.from("design-images").remove(chunk);
        }
        console.log(`Deleted ${imageStoragePaths.length} order images`);
      }
    } catch (storageErr) {
      // Non-fatal: log and continue. DB is already anonymized.
      console.error("Storage cleanup error (non-fatal):", storageErr);
    }

    // ── STEP 9: Handle auth user
    // STRATEGY: BAN (not hard-delete) the auth user.
    //
    // WHY BAN INSTEAD OF DELETE:
    // If profiles.id has an ON DELETE CASCADE FK to auth.users,
    // deleting the auth user would cascade-delete the profiles row,
    // and potentially the shops row — undoing all our anonymization.
    // Banning prevents login while keeping all DB rows intact.
    // 
    // Supabase ban: set ban_duration to a very long value.
    try {
      await supabaseAdmin.auth.admin.updateUser(user.id, {
        // @ts-ignore — ban_duration is valid Supabase Admin API param
        ban_duration: "876000h", // 100 years — effectively permanent
      });
      console.log(`Auth user ${user.id} banned successfully`);
    } catch (banErr) {
      // Non-fatal if ban fails — shop is already anonymized.
      // A banned user cannot log in via Supabase Auth.
      console.error("Auth ban error (non-fatal — shop already anonymized):", banErr);
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Account successfully deleted and anonymized",
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (err) {
    console.error("Unexpected error in delete-shop-account:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error", details: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
