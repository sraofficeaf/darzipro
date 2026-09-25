/// <reference path="../deno.d.ts" />
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import Stripe from 'https://esm.sh/stripe@14.25.0?target=deno';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, stripe-signature',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const provider = url.searchParams.get('provider') || 'stripe';

  if (provider !== 'stripe') {
    return new Response(
      JSON.stringify({ error: `Unsupported webhook provider: ${provider}` }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
  const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY') ?? '';
  const STRIPE_WEBHOOK_SECRET = Deno.env.get('STRIPE_WEBHOOK_SECRET') ?? '';

  if (!STRIPE_SECRET_KEY || !STRIPE_WEBHOOK_SECRET) {
    console.error('Stripe secrets not configured in environment variables');
    return new Response(
      JSON.stringify({ error: 'Stripe webhook configuration missing' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  const stripe = new Stripe(STRIPE_SECRET_KEY, {
    apiVersion: '2023-10-16',
    httpClient: Stripe.createFetchHttpClient(),
  });

  const signature = req.headers.get('stripe-signature');
  if (!signature) {
    return new Response(
      JSON.stringify({ error: 'Missing stripe-signature header' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  let event: Stripe.Event;
  const rawBody = await req.text();

  try {
    event = await stripe.webhooks.constructEventAsync(
      rawBody,
      signature,
      STRIPE_WEBHOOK_SECRET
    );
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`⚠️ Webhook signature verification failed: ${msg}`);
    return new Response(
      JSON.stringify({ error: `Signature verification failed: ${msg}` }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  // ── Shared fulfillment helper ─────────────────────────────────────────────
  async function fulfillByPaymentId(
    paymentId: string,
    isTest: boolean,
    newProviderRef?: string
  ): Promise<Response | null> {
    const { data: payment, error: findErr } = await supabase
      .from('unified_payments')
      .select('id, status, shop_id, purpose, provider_reference')
      .eq('id', paymentId)
      .maybeSingle();

    if (findErr || !payment) {
      console.warn(`fulfillByPaymentId: row not found for id=${paymentId}`);
      return null;
    }

    if (payment.status === 'succeeded') {
      console.log(`Payment ${paymentId} already succeeded. Idempotent exit.`);
      return new Response(JSON.stringify({ received: true, alreadyFulfilled: true }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const updates: Record<string, unknown> = { is_test: isTest };
    if (newProviderRef) {
      updates.provider_reference = newProviderRef;
    }

    await supabase.from('unified_payments').update(updates).eq('id', payment.id);

    const { error: fulfillErr } = await supabase.rpc('fulfill_payment', {
      p_payment_id: payment.id,
      p_is_test: isTest,
    });

    if (fulfillErr) {
      console.error(`fulfill_payment error for payment ${payment.id}:`, fulfillErr);
      return new Response(JSON.stringify({ error: fulfillErr.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    console.log(`Payment ${payment.id} successfully fulfilled.`);
    return new Response(JSON.stringify({ received: true, fulfilled: true }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // ── HANDLE PAYMENT INTENT SUCCEEDED ──────────────────────────────────────
  if (event.type === 'payment_intent.succeeded') {
    const paymentIntent = event.data.object as Stripe.PaymentIntent;
    const providerReference = paymentIntent.id;
    const isTest = event.livemode === false;

    console.log(`Processing payment_intent.succeeded for: ${providerReference}`);

    // 1. Try lookup by provider_reference (Payment Sheet path: pi_... stored in row)
    const { data: existingPayment, error: findErr } = await supabase
      .from('unified_payments')
      .select('id, status, shop_id, purpose')
      .eq('provider_code', 'stripe')
      .eq('provider_reference', providerReference)
      .maybeSingle();

    if (!findErr && existingPayment) {
      if (existingPayment.status === 'succeeded') {
        console.log(`Payment ${existingPayment.id} already succeeded. Idempotent return.`);
        return new Response(JSON.stringify({ received: true, alreadyFulfilled: true }), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
      await supabase.from('unified_payments').update({ is_test: isTest }).eq('id', existingPayment.id);
      const { error: fulfillErr } = await supabase.rpc('fulfill_payment', {
        p_payment_id: existingPayment.id,
        p_is_test: isTest,
      });
      if (fulfillErr) {
        console.error(`fulfill_payment error:`, fulfillErr);
        return new Response(JSON.stringify({ error: fulfillErr.message }), {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
      console.log(`Payment ${existingPayment.id} fulfilled via payment_intent.succeeded.`);
      return new Response(JSON.stringify({ received: true, fulfilled: true }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 2. Fallback: look up by metadata.payment_id (Checkout Session path)
    // The PaymentIntent metadata was set to { payment_id, shop_id, purpose }
    // by create-checkout-session via payment_intent_data.metadata.
    const fallbackId = paymentIntent.metadata?.payment_id;
    if (fallbackId) {
      console.log(`payment_intent.succeeded: falling back to metadata.payment_id=${fallbackId}`);
      const result = await fulfillByPaymentId(fallbackId, isTest, paymentIntent.id);
      if (result) return result;
    }

    console.warn(`payment_intent.succeeded: no row found for ${providerReference}`);
    return new Response(JSON.stringify({ received: true, warning: 'Payment row not found' }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // ── HANDLE CHECKOUT SESSION COMPLETED ────────────────────────────────────
  if (event.type === 'checkout.session.completed') {
    const session = event.data.object as Stripe.Checkout.Session;
    const isTest = event.livemode === false;

    console.log(`Processing checkout.session.completed for session: ${session.id}`);

    const paymentId = session.metadata?.payment_id;
    if (!paymentId) {
      console.warn(`checkout.session.completed: no payment_id in metadata for session ${session.id}`);
      return new Response(JSON.stringify({ received: true, warning: 'No payment_id in session metadata' }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const piId = typeof session.payment_intent === 'string' ? session.payment_intent : undefined;
    const result = await fulfillByPaymentId(paymentId, isTest, piId);
    if (result) return result;

    return new Response(JSON.stringify({ received: true, warning: 'Payment row not found' }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // ── HANDLE PAYMENT INTENT FAILED ─────────────────────────────────────────
  if (event.type === 'payment_intent.payment_failed') {
    const paymentIntent = event.data.object as Stripe.PaymentIntent;
    const providerReference = paymentIntent.id;
    const failureMsg = paymentIntent.last_payment_error?.message || 'Payment failed';
    const isTest = event.livemode === false;

    console.log(`Processing payment_intent.payment_failed for: ${providerReference}: ${failureMsg}`);

    // Try both lookup paths: provider_reference (pi_...) and metadata.payment_id
    await supabase
      .from('unified_payments')
      .update({ status: 'failed', failure_reason: failureMsg, is_test: isTest })
      .eq('provider_code', 'stripe')
      .eq('provider_reference', providerReference);

    // Also update via payment_id if this came from a Checkout Session
    const fallbackId = paymentIntent.metadata?.payment_id;
    if (fallbackId) {
      await supabase
        .from('unified_payments')
        .update({ status: 'failed', failure_reason: failureMsg, is_test: isTest })
        .eq('id', fallbackId);
    }
  }

  return new Response(JSON.stringify({ received: true }), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
});
