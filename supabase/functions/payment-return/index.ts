/// <reference path="../deno.d.ts" />
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

// UUID v4 validation regex — used to validate payment_id before any use.
// payment_id is never reflected raw into HTML (XSS prevention).
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function buildPage(isSuccess: boolean): string {
  const icon = isSuccess ? '✓' : '✕';
  const iconColor = isSuccess ? '#10B981' : '#F5A623';
  const iconBg = isSuccess ? 'rgba(16,185,129,0.12)' : 'rgba(245,166,35,0.12)';
  const heading = isSuccess ? 'Payment Complete' : 'Payment Cancelled';
  const body = isSuccess
    ? 'Your payment was processed successfully. You can close this tab and return to Darzi Pro.'
    : 'Your payment was cancelled. You can close this tab and return to Darzi Pro.';

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${heading} — Darzi Pro</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    html, body {
      height: 100%;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      background: #0B1525;
      color: #E2E8F0;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100dvh;
    }
    .card {
      background: #111D30;
      border: 1px solid rgba(255,255,255,0.08);
      border-radius: 20px;
      padding: 48px 40px;
      max-width: 440px;
      width: 90%;
      text-align: center;
      box-shadow: 0 20px 60px rgba(0,0,0,0.4);
    }
    .icon-wrap {
      width: 72px;
      height: 72px;
      border-radius: 50%;
      background: ${iconBg};
      display: flex;
      align-items: center;
      justify-content: center;
      margin: 0 auto 24px;
      font-size: 32px;
      color: ${iconColor};
      border: 2px solid ${iconColor};
    }
    h1 {
      font-size: 22px;
      font-weight: 700;
      color: #F1F5F9;
      margin-bottom: 12px;
    }
    p {
      font-size: 15px;
      color: #94A3B8;
      line-height: 1.6;
    }
    .brand {
      margin-top: 36px;
      font-size: 12px;
      color: #475569;
      letter-spacing: 0.04em;
    }
    .brand span {
      color: #F5A623;
      font-weight: 600;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="icon-wrap">${icon}</div>
    <h1>${heading}</h1>
    <p>${body}</p>
    <div class="brand">Powered by <span>Darzi Pro</span></div>
  </div>
</body>
</html>`;
}

serve((req: Request) => {
  // This is a display-only page. It NEVER writes to the database,
  // calls any RPC, or fulfils any payment. Fulfilment happens only
  // through the signed Stripe webhook.

  const url = new URL(req.url);
  const rawStatus = url.searchParams.get('status') ?? '';
  const rawPaymentId = url.searchParams.get('payment_id') ?? '';

  // Validate status — only accept the two known literals.
  const isSuccess = rawStatus === 'success';
  const isCancel = rawStatus === 'cancel';

  if (!isSuccess && !isCancel) {
    // Unknown status — show neutral page, do not reflect the unknown value.
    return new Response(buildPage(false), {
      status: 200,
      headers: { 'Content-Type': 'text/html; charset=utf-8' },
    });
  }

  // Validate payment_id as UUID format — never render raw query-string
  // values into HTML (XSS prevention). The value is discarded if invalid.
  const paymentIdIsValid = UUID_RE.test(rawPaymentId);
  if (rawPaymentId && !paymentIdIsValid) {
    console.warn(`payment-return: invalid payment_id format received (discarded)`);
  }
  // payment_id is intentionally not reflected into the HTML page.
  // It was already recorded server-side at session creation.

  return new Response(buildPage(isSuccess), {
    status: 200,
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      // Prevent the page from being embedded in iframes
      'X-Frame-Options': 'DENY',
      'X-Content-Type-Options': 'nosniff',
      // No caching — Stripe may redirect here immediately after payment
      'Cache-Control': 'no-store',
    },
  });
});
