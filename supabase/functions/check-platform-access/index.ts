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
    // ── SECURITY: Verify caller has a valid Supabase Auth session ────────────
    const authHeader = req.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return new Response(
        JSON.stringify({ allowed: false, error: 'Unauthorized: No auth token' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

    // Verify caller JWT
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: authError } = await callerClient.auth.getUser();
    if (authError || !user) {
      return new Response(
        JSON.stringify({ allowed: false, error: 'Unauthorized: Invalid session' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const { shop_id, platform } = await req.json();

    if (!shop_id || !platform) {
      return new Response(
        JSON.stringify({ error: 'shop_id and platform are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // ── SECURITY: Verify caller owns this shop_id ────────────────────────────
    const supabase = createClient(supabaseUrl, serviceKey);
    const { data: profileData, error: profileError } = await supabase
      .from('profiles')
      .select('shop_id')
      .eq('id', user.id)
      .maybeSingle();

    if (profileError || !profileData || profileData.shop_id !== shop_id) {
      return new Response(
        JSON.stringify({ allowed: false, error: 'Forbidden: You do not own this shop' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // Get shop's license plan
    const { data: license, error } = await supabase
      .from('licenses')
      .select('plan, status')
      .eq('shop_id', shop_id)
      .eq('status', 'active')
      .maybeSingle();

    if (error) {
      return new Response(
        JSON.stringify({ allowed: false, reason: 'db_error', error: error.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    if (!license) {
      // No license found — allow access (might be new shop or admin)
      return new Response(
        JSON.stringify({ allowed: true, plan: null }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const plan = license.plan as string;
    const restrictedPlatforms = ['windows', 'web'];

    if (plan === 'mobile_only' && restrictedPlatforms.includes(platform)) {
      return new Response(
        JSON.stringify({
          allowed: false,
          reason: 'mobile_only_restriction',
          plan: plan,
          message: 'Your plan (Mobile Only) does not include Website/Windows access.',
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    return new Response(
      JSON.stringify({ allowed: true, plan: plan }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ allowed: true, error: String(err) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});

