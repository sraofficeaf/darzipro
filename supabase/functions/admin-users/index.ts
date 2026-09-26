/// <reference path="../deno.d.ts" />
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

    // ── STEP 1: Verify caller has an active session via JWT ─────────
    const authHeader = req.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized: No auth token provided' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const callerJwt = authHeader.replace('Bearer ', '');
    const callerClient = createClient(SUPABASE_URL, supabaseAnonKey, {
      global: { headers: { Authorization: `Bearer ${callerJwt}` } },
    });

    const { data: { user: callerUser }, error: authError } = await callerClient.auth.getUser();
    if (authError || !callerUser) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized: Invalid session' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // ── STEP 2: Verify caller is an admin in admin_users ────────────
    const supabaseAdmin = createClient(SUPABASE_URL, supabaseServiceRoleKey);
    const { data: adminUser, error: adminErr } = await supabaseAdmin
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

    const body = await req.json().catch(() => ({}));
    const action = body.action || 'list';

    // ── ACTION: LIST USERS ──────────────────────────────────────────
    if (action === 'list') {
      // 1. List auth users from GoTrue
      const { data: { users: authUsers }, error: listErr } = await supabaseAdmin.auth.admin.listUsers({
        page: 1,
        perPage: 1000,
      });

      if (listErr) {
        return new Response(
          JSON.stringify({ error: `GoTrue error: ${listErr.message}` }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // 2. Fetch profiles with joined shop info
      const { data: profiles, error: profErr } = await supabaseAdmin
        .from('profiles')
        .select('id, full_name, role, created_at, shop_id, shops(id, name, phone, currency, plan_code, subscription_status)');

      if (profErr) {
        return new Response(
          JSON.stringify({ error: `Database error: ${profErr.message}` }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // Index profiles by user id
      const profileMap = new Map();
      for (const p of profiles || []) {
        profileMap.set(p.id, p);
      }

      // Combine auth users with profile and shop
      const combined = authUsers.map((u: any) => {
        const prof = profileMap.get(u.id) || {};
        return {
          id: u.id,
          email: u.email,
          full_name: prof.full_name || u.user_metadata?.full_name || u.email?.split('@')[0] || 'Unknown',
          role: prof.role || 'user',
          email_confirmed_at: u.email_confirmed_at,
          banned_until: u.banned_until,
          created_at: u.created_at,
          last_sign_in_at: u.last_sign_in_at,
          shop_id: prof.shop_id || null,
          shops: prof.shops || null,
        };
      });

      return new Response(
        JSON.stringify({ success: true, users: combined }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // ── ACTION: CREATE SHOP OWNER ───────────────────────────────────
    if (action === 'create') {
      const { email, password, shopName, ownerName, phone } = body;
      if (!email || !password || !shopName) {
        return new Response(
          JSON.stringify({ error: 'Missing email, password, or shopName' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // 1. Create auth user with auto confirmed email
      const { data: newAuth, error: createAuthErr } = await supabaseAdmin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { full_name: ownerName },
      });

      if (createAuthErr || !newAuth.user) {
        return new Response(
          JSON.stringify({ error: createAuthErr?.message || 'Failed to create auth user' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const userId = newAuth.user.id;

      // 2. Create shop
      const inviteCode = `DARZI-INV-${Math.random().toString(36).substring(2, 8).toUpperCase()}`;
      const { data: newShop, error: shopErr } = await supabaseAdmin
        .from('shops')
        .insert({
          name: shopName,
          phone: phone || null,
          currency: 'PKR',
          invite_code: inviteCode,
          plan_code: 'trial',
          subscription_status: 'trial',
        })
        .select()
        .single();

      if (shopErr || !newShop) {
        // Rollback auth user
        await supabaseAdmin.auth.admin.deleteUser(userId);
        return new Response(
          JSON.stringify({ error: `Failed to create shop: ${shopErr?.message}` }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // 3. Create or update profile
      const { error: profErr } = await supabaseAdmin
        .from('profiles')
        .upsert({
          id: userId,
          shop_id: newShop.id,
          full_name: ownerName || email.split('@')[0],
          role: 'owner',
        });

      if (profErr) {
        return new Response(
          JSON.stringify({ error: `Failed to create profile: ${profErr.message}` }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      return new Response(
        JSON.stringify({ success: true, userId, shopId: newShop.id }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // ── ACTION: BLOCK USER ──────────────────────────────────────────
    if (action === 'block') {
      const { userId, duration } = body;
      const banDuration = duration || '876600h'; // default 100 years
      const { error: blockErr } = await supabaseAdmin.auth.admin.updateUserById(userId, {
        ban_duration: banDuration,
      });

      if (blockErr) {
        return new Response(
          JSON.stringify({ error: blockErr.message }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      return new Response(
        JSON.stringify({ success: true }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // ── ACTION: UNBLOCK USER ────────────────────────────────────────
    if (action === 'unblock') {
      const { userId } = body;
      const { error: unblockErr } = await supabaseAdmin.auth.admin.updateUserById(userId, {
        ban_duration: 'none',
      });

      if (unblockErr) {
        return new Response(
          JSON.stringify({ error: unblockErr.message }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      return new Response(
        JSON.stringify({ success: true }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // ── ACTION: DELETE USER ─────────────────────────────────────────
    if (action === 'delete') {
      const { userId } = body;
      const { error: delErr } = await supabaseAdmin.auth.admin.deleteUser(userId);

      if (delErr) {
        return new Response(
          JSON.stringify({ error: delErr.message }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // Also clean profile
      await supabaseAdmin.from('profiles').delete().eq('id', userId);

      return new Response(
        JSON.stringify({ success: true }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // ── ACTION: RESEND CONFIRMATION EMAIL ───────────────────────────
    if (action === 'resend_confirmation') {
      const { email } = body;
      if (!email) {
        return new Response(
          JSON.stringify({ error: 'Missing email' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const { error: resendErr } = await supabaseAdmin.auth.resend({
        type: 'signup',
        email,
      });

      if (resendErr) {
        return new Response(
          JSON.stringify({ error: resendErr.message }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      return new Response(
        JSON.stringify({ success: true }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // ── ACTION: MARK EMAIL CONFIRMED ────────────────────────────────
    if (action === 'confirm_email') {
      const { userId } = body;
      const { error: confErr } = await supabaseAdmin.auth.admin.updateUserById(userId, {
        email_confirm: true,
      });

      if (confErr) {
        return new Response(
          JSON.stringify({ error: confErr.message }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      return new Response(
        JSON.stringify({ success: true }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify({ error: `Unknown action: ${action}` }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message || String(err) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
