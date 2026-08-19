/// <reference path="../deno.d.ts" />
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-admin-email, x-admin-hash',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
    const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

    // ── STEP 1: Verify caller has a real Supabase Auth session via JWT ─────
    const authHeader = req.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized: No auth token provided' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const callerJwt = authHeader.replace('Bearer ', '');
    const callerClient = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${callerJwt}` } },
    });

    const { data: { user: callerUser }, error: authError } = await callerClient.auth.getUser();
    if (authError || !callerUser) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized: Invalid session' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // ── STEP 2: Confirm caller exists in admin_users table ──────────────────
    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const { data: adminUser, error: adminErr } = await supabase
      .from('admin_users')
      .select('id, email, role')
      .eq('email', callerUser.email!)
      .maybeSingle();

    if (adminErr || !adminUser || (adminUser.role !== 'superadmin' && adminUser.role !== 'admin')) {
      return new Response(
        JSON.stringify({ error: 'Forbidden: Valid admin account required' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const body = await req.json();
    const { action } = body;

    // ── 1. FETCH REPORTS DATA ──────────────────────────────────────────────────
    if (action === 'fetch_reports') {
      const { data: pubRegs } = await supabase.from('public_registrations').select('*').eq('status', 'approved');
      const { data: upgrades } = await supabase.from('upgrade_requests').select('*').eq('status', 'approved');
      const { data: storage } = await supabase.from('storage_addon_payments').select('*');
      const { data: licenses } = await supabase.from('licenses').select('*');
      const { data: payouts } = await supabase.from('profit_payouts').select('*');
      const { data: earnings } = await supabase.from('profit_earnings').select('*, inviter_shop:shops(name)');

      return new Response(
        JSON.stringify({
          public_registrations: pubRegs || [],
          upgrades: upgrades || [],
          storage_payments: storage || [],
          licenses: licenses || [],
          payouts: payouts || [],
          earnings: earnings || [],
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // ── 2. FETCH PENDING APPROVALS ──────────────────────────────────────────────
    if (action === 'fetch_approvals') {
      const { data: pendingRegs } = await supabase.from('public_registrations').select('*').eq('status', 'pending_admin_review');
      const { data: pendingUpgrades } = await supabase.from('upgrade_requests').select('*').eq('status', 'pending_approval');

      return new Response(
        JSON.stringify({
          pending_registrations: pendingRegs || [],
          pending_upgrades: pendingUpgrades || [],
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // ── 3. FETCH SHOPS ──────────────────────────────────────────────────────────
    if (action === 'fetch_shops') {
      const { data: shops } = await supabase.from('shops').select('*, licenses(*)').order('created_at', { ascending: false });
      return new Response(
        JSON.stringify(shops || []),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // ── 4. FETCH LICENSES ───────────────────────────────────────────────────────
    if (action === 'fetch_licenses') {
      const { data: licenses } = await supabase.from('licenses').select('*').order('created_at', { ascending: false });
      return new Response(
        JSON.stringify(licenses || []),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // ── 5. APPROVE REGISTRATION ────────────────────────────────────────────────
    if (action === 'approve_registration') {
      const { registration_id, shop_name, owner_name, phone, plan } = body;

      // Update public registration status
      await supabase.from('public_registrations').update({ status: 'approved', reviewed_at: new Date().toISOString() }).eq('id', registration_id);

      // Create shop
      const inviteCode = `DARZI-INV-${Math.random().toString(36).substring(2, 8).toUpperCase()}`;
      const { data: shop } = await supabase.from('shops').insert({
        name: shop_name,
        phone: phone,
        invite_code: inviteCode,
        status: 'active',
      }).select().single();

      if (shop) {
        // Create license with shop_id FK
        const expiryDate = new Date();
        expiryDate.setDate(expiryDate.getDate() + 365);

        await supabase.from('licenses').insert({
          shop_id: shop.id,
          license_key: `DARZI-${Math.random().toString(36).substring(2, 6).toUpperCase()}-${Math.random().toString(36).substring(2, 6).toUpperCase()}`,
          shop_name: shop_name,
          plan: plan || 'full_access',
          status: 'active',
          expires_at: expiryDate.toISOString(),
          payment_ref: 'REG-APPROVED',
        });
      }

      return new Response(
        JSON.stringify({ success: true, shop_id: shop?.id }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // ── 6. APPROVE UPGRADE ─────────────────────────────────────────────────────
    if (action === 'approve_upgrade') {
      const { upgrade_id, shop_id, new_plan } = body;

      await supabase.from('upgrade_requests').update({ status: 'approved', reviewed_at: new Date().toISOString() }).eq('id', upgrade_id);
      await supabase.from('licenses').update({ plan: new_plan }).eq('shop_id', shop_id);

      return new Response(
        JSON.stringify({ success: true }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify({ error: 'Unknown action' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
