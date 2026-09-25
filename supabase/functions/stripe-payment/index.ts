/// <reference path="../deno.d.ts" />
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import Stripe from 'https://esm.sh/stripe@14.25.0?target=deno';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// ── Shared helper: insert a unified_payments row ──────────────────────────────
async function createUnifiedPaymentsRow(
  supabase: ReturnType<typeof createClient>,
  {
    shop_id,
    purpose,
    amount_minor,
    currency,
    provider_reference,
    is_test,
    metadata,
  }: {
    shop_id: string;
    purpose: string;
    amount_minor: number;
    currency: string;
    provider_reference: string;
    is_test: boolean;
    metadata?: Record<string, unknown>;
  }
): Promise<{ id: string | null; error: unknown }> {
  const { data, error } = await supabase
    .from('unified_payments')
    .insert({
      shop_id,
      provider_code: 'stripe',
      purpose,
      amount_minor,
      currency: currency.toUpperCase(),
      provider_reference,
      status: 'pending',
      is_test,
      metadata: metadata ?? {},
    })
    .select('id')
    .single();

  return { id: data?.id ?? null, error };
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
  const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY') ?? '';
  const STRIPE_PUBLISHABLE_KEY = Deno.env.get('STRIPE_PUBLISHABLE_KEY') ?? '';

  const url = new URL(req.url);

  try {
    let body: Record<string, unknown> = {};
    if (req.method === 'POST') {
      try { body = await req.json(); } catch (_) {}
    }

    const action = (body.action as string) || url.searchParams.get('action') || 'create-intent';

    // ── 1. HEALTH CHECK ───────────────────────────────────────────────────
    if (action === 'health') {
      const STRIPE_WEBHOOK_SECRET = Deno.env.get('STRIPE_WEBHOOK_SECRET') ?? '';
      return new Response(
        JSON.stringify({
          configured: !!(STRIPE_SECRET_KEY && STRIPE_WEBHOOK_SECRET),
          secretKeySet: !!STRIPE_SECRET_KEY,
          webhookSecretSet: !!STRIPE_WEBHOOK_SECRET,
          publishableKeySet: !!STRIPE_PUBLISHABLE_KEY,
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (!STRIPE_SECRET_KEY) {
      return new Response(
        JSON.stringify({ error: 'Stripe is not configured on the server (STRIPE_SECRET_KEY missing)' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const stripe = new Stripe(STRIPE_SECRET_KEY, {
      apiVersion: '2023-10-16',
      httpClient: Stripe.createFetchHttpClient(),
    });

    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    // ── 2. CREATE PAYMENT INTENT (native mobile Payment Sheet) ────────────
    if (action === 'create-intent') {
      const { shop_id, amount_minor, currency, purpose, metadata } = body as Record<string, unknown>;

      if (!shop_id || !amount_minor || !currency || !purpose) {
        return new Response(
          JSON.stringify({ error: 'Missing required parameters (shop_id, amount_minor, currency, purpose)' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const amountInt = Math.round(Number(amount_minor));
      if (!Number.isInteger(amountInt) || amountInt <= 0) {
        return new Response(
          JSON.stringify({ error: 'amount_minor must be a positive integer' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const paymentIntent = await stripe.paymentIntents.create({
        amount: amountInt,
        currency: (currency as string).toLowerCase(),
        automatic_payment_methods: { enabled: true },
        metadata: {
          shop_id: shop_id as string,
          purpose: purpose as string,
          app: 'darzi_pro',
          ...((metadata as Record<string, unknown>) || {}),
        },
      });

      const isTestPayment = paymentIntent.livemode === false;
      const { id: unifiedPaymentId, error: insertErr } = await createUnifiedPaymentsRow(supabase, {
        shop_id: shop_id as string,
        purpose: purpose as string,
        amount_minor: amountInt,
        currency: currency as string,
        provider_reference: paymentIntent.id,
        is_test: isTestPayment,
        metadata: {
          stripe_payment_intent_id: paymentIntent.id,
          ...((metadata as Record<string, unknown>) || {}),
        },
      });

      if (insertErr) {
        console.error('Error inserting unified_payments row:', insertErr);
      }

      return new Response(
        JSON.stringify({
          clientSecret: paymentIntent.client_secret,
          providerReference: paymentIntent.id,
          publishableKey: STRIPE_PUBLISHABLE_KEY,
          unifiedPaymentId,
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // ── 3. CREATE CHECKOUT SESSION (web / desktop) ────────────────────────
    if (action === 'create-checkout-session') {
      const { shop_id, amount_minor, currency, purpose, metadata } = body as Record<string, unknown>;

      if (!shop_id || !amount_minor || !currency || !purpose) {
        return new Response(
          JSON.stringify({ error: 'Missing required parameters (shop_id, amount_minor, currency, purpose)' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const amountInt = Math.round(Number(amount_minor));
      if (!Number.isInteger(amountInt) || amountInt <= 0) {
        return new Response(
          JSON.stringify({ error: 'amount_minor must be a positive integer' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // Build a human-readable product name from purpose
      const purposeStr = purpose as string;
      const productName =
        purposeStr === 'subscriptionMonthly' ? 'Monthly Subscription — Darzi Pro' :
        purposeStr === 'foundingActivation'  ? 'Founding Member Lifetime Activation — Darzi Pro' :
        purposeStr === 'storageMonthly'      ? 'Monthly Storage Add-on — Darzi Pro' :
        purposeStr === 'storageAnnual'       ? 'Annual Storage Add-on — Darzi Pro' :
                                               `Darzi Pro — ${purposeStr}`;

      // FUNCTIONS_BASE for return URLs — must be public URL, not internal Docker SUPABASE_URL
      const publicBase = Deno.env.get('SUPABASE_PUBLIC_URL') || 'https://darzipro-db.isaif.cloud';
      const functionsBase = `${publicBase}/functions/v1`;

      // Insert the unified_payments row FIRST so we have a payment_id
      // to embed in the session metadata. We use the Checkout Session ID
      // as provider_reference initially; the webhook updates via metadata.payment_id.
      // We need a placeholder provider_reference until the session is created.
      // Strategy: insert with provider_reference = 'pending_checkout', then
      // update after session creation.
      const { data: newRow, error: insertErr } = await supabase
        .from('unified_payments')
        .insert({
          shop_id: shop_id as string,
          provider_code: 'stripe',
          purpose: purposeStr,
          amount_minor: amountInt,
          currency: (currency as string).toUpperCase(),
          provider_reference: 'pending_checkout',
          status: 'pending',
          is_test: true, // overwritten after session creation from livemode
          metadata: {
            ...((metadata as Record<string, unknown>) || {}),
          },
        })
        .select('id')
        .single();

      if (insertErr || !newRow?.id) {
        console.error('Error inserting unified_payments row:', insertErr);
        return new Response(
          JSON.stringify({ error: 'Failed to create payment record' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const paymentId = newRow.id as string;

      // CRITICAL: metadata must be set on BOTH the Session AND payment_intent_data
      // The existing webhook handles payment_intent.succeeded and reads
      // metadata.payment_id from the PaymentIntent — not from the Session.
      const sharedMetadata = {
        payment_id: paymentId,
        shop_id: shop_id as string,
        purpose: purposeStr,
        app: 'darzi_pro',
      };

      const session = await stripe.checkout.sessions.create({
        mode: 'payment',
        line_items: [
          {
            price_data: {
              currency: (currency as string).toLowerCase(),
              unit_amount: amountInt,
              product_data: {
                name: productName,
              },
            },
            quantity: 1,
          },
        ],
        metadata: sharedMetadata,
        payment_intent_data: {
          // CRITICAL: propagate metadata to PaymentIntent so that the
          // existing payment_intent.succeeded webhook handler can look up
          // the unified_payments row by metadata.payment_id.
          metadata: sharedMetadata,
        },
        success_url: `${functionsBase}/payment-return?status=success&payment_id=${paymentId}`,
        cancel_url: `${functionsBase}/payment-return?status=cancel&payment_id=${paymentId}`,
      });

      const isTestPayment = session.livemode === false;

      // Update the row: set provider_reference to the Checkout Session ID
      // and correct the is_test flag now that we have the session's livemode.
      await supabase
        .from('unified_payments')
        .update({
          provider_reference: session.id,
          is_test: isTestPayment,
        })
        .eq('id', paymentId);

      console.log(`Checkout session created: ${session.id}, payment_id: ${paymentId}, is_test: ${isTestPayment}`);

      return new Response(
        JSON.stringify({
          url: session.url,
          payment_id: paymentId,
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // ── 3B. RETRIEVE CHECKOUT SESSION (DEBUG / INSPECTION) ────────────────
    if (action === 'retrieve-session') {
      const sessionId = (body.session_id as string) || url.searchParams.get('session_id');
      if (!sessionId) {
        return new Response(
          JSON.stringify({ error: 'Missing session_id' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
      const session = await stripe.checkout.sessions.retrieve(sessionId);
      return new Response(
        JSON.stringify(session, null, 2),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // ── 4. CHECK STATUS ───────────────────────────────────────────────────
    if (action === 'check-status') {
      const providerReference =
        (body.provider_reference as string) || url.searchParams.get('provider_reference');
      if (!providerReference) {
        return new Response(
          JSON.stringify({ error: 'Missing provider_reference' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // providerReference may be:
      // 1) Stripe PaymentIntent ID (pi_...)
      if (providerReference.startsWith('pi_')) {
        const paymentIntent = await stripe.paymentIntents.retrieve(providerReference);
        let mappedStatus = 'pending';
        switch (paymentIntent.status) {
          case 'succeeded':         mappedStatus = 'succeeded'; break;
          case 'processing':        mappedStatus = 'processing'; break;
          case 'requires_payment_method':
          case 'canceled':          mappedStatus = 'cancelled'; break;
          default:                  mappedStatus = 'pending'; break;
        }
        return new Response(
          JSON.stringify({
            status: mappedStatus,
            stripeStatus: paymentIntent.status,
            amount: paymentIntent.amount,
            currency: paymentIntent.currency,
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // 2) Stripe Checkout Session ID (cs_...)
      if (providerReference.startsWith('cs_')) {
        const session = await stripe.checkout.sessions.retrieve(providerReference);
        let mappedStatus = 'pending';
        if (session.payment_status === 'paid' || session.status === 'complete') {
          mappedStatus = 'succeeded';
        } else if (session.status === 'expired') {
          mappedStatus = 'expired';
        }
        return new Response(
          JSON.stringify({
            status: mappedStatus,
            sessionStatus: session.status,
            paymentStatus: session.payment_status,
            amount: session.amount_total,
            currency: session.currency,
            paymentIntent: session.payment_intent,
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // UUID path: query unified_payments directly
      const { data: row } = await supabase
        .from('unified_payments')
        .select('status, amount_minor, currency')
        .eq('id', providerReference)
        .maybeSingle();

      return new Response(
        JSON.stringify({
          status: row?.status ?? 'pending',
          amount: row?.amount_minor,
          currency: row?.currency,
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify({ error: `Unknown action: ${action}` }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Internal server error';
    console.error('stripe-payment function error:', err);
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
