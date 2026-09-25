# Stripe Production Go-Live Checklist

This checklist documents every configuration, environment variable, database setting, and verification query required when transitioning Darzi Pro's payment infrastructure from Stripe Test/Sandbox mode to Stripe Live production mode.

> [!CAUTION]
> **CRITICAL GO-LIVE HAZARD: LIVE-SHOP TEST BYPASS RISK**
> The unified payment fulfillment engine protects production subscriptions by strictly bypassing `billing_cycle_end` extensions whenever `is_test = true` on a live shop.
> **If Stripe is switched to live keys but the database provider mode remains `"test"`, a real paying customer will have their card charged, the payment row will be recorded as `succeeded`, but `fulfill_payment` will BYPASS subscription activation!**
> You MUST execute Step 1 below immediately upon switching keys.

---

## 1. Database Provider Mode Configuration (MANDATORY FIRST STEP)

The database trigger `trg_unified_payments_set_test_mode` sets `is_test` on every incoming payment using `payment_providers.config->>'mode'`. The very first action after switching keys is setting this mode to `"live"`.

### A. Execute the Live Mode Update
```sql
UPDATE payment_providers
SET config = jsonb_set(
  COALESCE(config, '{}'::jsonb),
  '{mode}',
  '"live"'
),
updated_at = NOW()
WHERE code = 'stripe';
```

### B. Mandatory Verification Query
```sql
SELECT code, enabled, is_instant, config->>'mode' AS active_mode, config, updated_at
FROM payment_providers
WHERE code = 'stripe';
```
*Expected Result:* `active_mode` MUST show `live`. If it shows `test` or null, live customer payments will be bypassed.

---

## 2. Coolify & Edge Functions Environment Variables

Update the following secrets in the Coolify Edge Functions service container (`edge-functions` service):

| Variable Name | Environment | Description | Example Format |
| :--- | :--- | :--- | :--- |
| `STRIPE_SECRET_KEY` | Production | Live Restricted or Secret API key from Stripe Dashboard | `sk_live_51...` |
| `STRIPE_PUBLISHABLE_KEY` | Production | Live Publishable API key | `pk_live_51...` |
| `STRIPE_WEBHOOK_SECRET` | Production | Signing secret for the live webhook endpoint | `whsec_...` |

> [!IMPORTANT]
> After saving the environment variables in Coolify, restart the `edge-functions` service container so the Deno runtime loads the new live keys into memory.

---

## 3. Stripe Live Dashboard Webhook Configuration

1. In the Stripe Dashboard, toggle from **Test mode** to **Live mode**.
2. Navigate to **Developers → Webhooks → Add an endpoint**.
3. Set **Endpoint URL** to:
   ```
   https://darzipro-db.isaif.cloud/functions/v1/payment-webhook
   ```
4. Under **Events to send**, select:
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`
5. Click **Add endpoint**.
6. Reveal the **Signing secret** (`whsec_...`) and save it into Coolify's `STRIPE_WEBHOOK_SECRET`.

---

## 4. Deploy Updated Edge Functions to VPS

Ensure the production VPS volume contains the authoritative Edge Function scripts that automatically pass `is_test: paymentIntent.livemode === false` and `is_test: (event.livemode === false)`:

```powershell
# From local repository root:
node bin/deploy_all_functions.js
```

---

## 5. First Live Payment Verification (Run Immediately Post-Launch)

Immediately after processing the first real customer payment, execute this verification suite against the database to guarantee `is_test = false`, access is granted, no bypass occurred, and revenue is recorded:

### A. Verify Payment Row & Guard Status
```sql
SELECT 
  id,
  shop_id,
  provider_code,
  purpose,
  amount_minor,
  currency,
  status,
  is_test,
  failure_reason,
  created_at,
  completed_at
FROM unified_payments
ORDER BY created_at DESC
LIMIT 1;
```
*Expected Result:*
- `status` = `'succeeded'`
- `is_test` = `false`
- `failure_reason` IS NULL (must NOT contain `'BYPASSED_TEST_PAYMENT_ON_LIVE_SHOP'`).

### B. Verify Zero Critical Audit Alerts
```sql
SELECT id, severity, category, title, message, created_at
FROM admin_audit_logs
WHERE payment_id = (SELECT id FROM unified_payments ORDER BY created_at DESC LIMIT 1);
```
*Expected Result:* `0 rows returned`. If a row exists with category `payment_test_bypass`, the live payment was incorrectly flagged as test mode!

### C. Verify Shop Subscription Activation
```sql
SELECT 
  s.id,
  s.name,
  s.subscription_status,
  s.plan_code,
  s.billing_cycle_start,
  s.billing_cycle_end,
  s.is_test
FROM shops s
WHERE s.id = (SELECT shop_id FROM unified_payments ORDER BY created_at DESC LIMIT 1);
```
*Expected Result:*
- `subscription_status` = `'active'`
- `billing_cycle_end` is extended by 1 month into the future
- `is_test` = `false`

### D. Verify Total Revenue Reporting Across Platform
```sql
SELECT total_revenue
FROM get_admin_reports_data();
```
*Expected Result:* `total_revenue` is non-zero and reflects the live payment amount in PKR major units.

### E. Verify Invite Profit Distribution (if shop was invited)
```sql
SELECT 
  pe.id,
  pe.source_shop_id,
  pe.target_shop_id,
  pe.level,
  pe.percentage,
  pe.earning_amount_pkr,
  pe.created_at
FROM profit_earnings pe
WHERE pe.unified_payment_id = (SELECT id FROM unified_payments ORDER BY created_at DESC LIMIT 1)
ORDER BY pe.level ASC;
```
*Expected Result:* Profit rows exist with calculated profit earnings for eligible inviter levels.
