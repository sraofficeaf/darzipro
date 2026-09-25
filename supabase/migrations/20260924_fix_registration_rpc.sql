-- Migration: Fix register_new_shop_free_trial + stranded-account protection
-- 2026-09-24
--
-- Root cause confirmed by live schema probe:
--   shops.owner_name    → does not exist (never was in the live table)
--   shops.invited_by_code → was dropped in 20260922_agency_system.sql:12
--   Both were referenced in the RPC INSERT → every signup failed silently.
--
-- Column-by-column audit of shops (live):
--   name                ✓  address          ✓  phone            ✓
--   city                ✓  currency         ✓  invite_code      ✓
--   plan_code           ✓  subscription_status ✓ trial_started_at ✓
--   created_at          ✓
--   owner_name          ✗  REMOVED — stored in profiles.full_name
--   invited_by_code     ✗  REMOVED — column dropped
--
-- Column-by-column audit of profiles (live):
--   id ✓  shop_id ✓  full_name ✓  role ✓  created_at ✓
--
-- Column-by-column audit of shop_usage_cycles (live):
--   shop_id ✓  cycle_start ✓  cycle_end ✓  orders_count ✓
--   active_customers_snapshot ✓  plan_code_at_start ✓  plan_code_at_end ✓
--   amount_due_pkr ✓  payment_status ✓
--
-- Column-by-column audit of public_registrations (live):
--   shop_name ✓  owner_name ✓  email ✓  phone ✓  address ✓
--   plan_selected ✓  status ✓  email_verified ✓  invite_code_used ✓  created_at ✓
--
-- Column-by-column audit of admin_audit_logs (live):
--   severity ✓  category ✓  shop_id ✓  title ✓  message ✓  metadata ✓

-- ── 0. SCHEMA REPAIR: Allow 'trial' in public_registrations.plan_selected ──
alter table public_registrations drop constraint if exists public_registrations_plan_selected_check;
alter table public_registrations add constraint public_registrations_plan_selected_check
  check (plan_selected is null or plan_selected = any (array['mobile_only'::text, 'full_access'::text, 'trial'::text, 'founding'::text]));

-- ── 1. REWRITTEN RPC ─────────────────────────────────────────────────────────
create or replace function register_new_shop_free_trial(
  p_user_id     uuid,
  p_shop_name   text,
  p_owner_name  text,
  p_phone       text,
  p_address     text,
  p_city        text default null,
  p_invite_code text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_shop_id     uuid;
  v_invite_code text;
  v_user_email  text;
begin
  -- Validate inputs before touching any table
  if p_user_id is null then
    raise exception 'p_user_id is required';
  end if;
  if trim(coalesce(p_shop_name, '')) = '' then
    raise exception 'p_shop_name is required';
  end if;
  if trim(coalesce(p_owner_name, '')) = '' then
    raise exception 'p_owner_name is required';
  end if;

  -- Fetch email from auth.users (ensure the auth user exists)
  select email into v_user_email
  from auth.users where id = p_user_id;

  if not found or v_user_email is null then
    raise exception 'User % does not exist in auth.users', p_user_id;
  end if;

  -- 1. Generate unique 6-character invite code for this shop
  v_invite_code := upper(substring(
    md5(random()::text || clock_timestamp()::text) from 1 for 6
  ));

  -- 2. Insert shop
  --    owner_name  → NOT a column; stored in profiles.full_name below
  --    invited_by_code → dropped in 20260922_agency_system; not inserted
  insert into shops (
    name, phone, address, city, currency,
    invite_code, status, plan_code, subscription_status, trial_started_at, created_at
  ) values (
    trim(p_shop_name), p_phone, p_address, p_city, 'PKR',
    v_invite_code, 'active', 'trial', 'trial', now(), now()
  )
  returning id into v_shop_id;

  -- 3. Insert owner profile — owner name lives here
  insert into profiles (id, shop_id, full_name, role, created_at)
  values (p_user_id, v_shop_id, trim(p_owner_name), 'owner', now())
  on conflict (id) do update set
    shop_id   = excluded.shop_id,
    full_name = excluded.full_name,
    role      = 'owner';

  -- 4. Create initial 14-day trial usage cycle
  insert into shop_usage_cycles (
    shop_id, cycle_start, cycle_end,
    orders_count, active_customers_snapshot,
    plan_code_at_start, plan_code_at_end,
    amount_due_pkr, payment_status
  ) values (
    v_shop_id, current_date, current_date + interval '14 days',
    0, 0, 'trial', 'trial', 0, 'waived'
  );

  -- 5. Record in public_registrations for admin visibility
  insert into public_registrations (
    shop_name, owner_name, email, phone, address,
    plan_selected, status, email_verified, invite_code_used,
    created_shop_id, created_at
  ) values (
    trim(p_shop_name), trim(p_owner_name), v_user_email,
    p_phone, p_address, 'trial', 'approved', true,
    p_invite_code, v_shop_id, now()
  );

  return jsonb_build_object(
    'success', true, 'shop_id', v_shop_id,
    'invite_code', v_invite_code, 'plan', 'trial'
  );

exception when others then
  -- In PostgreSQL PL/pgSQL, encountering an exception in a block rolls back
  -- writes made inside the BEGIN block before the exception.
  -- Log to admin_audit_logs with severity 'critical' so failures are visible in the admin panel.
  begin
    insert into admin_audit_logs (
      severity, category, shop_id, title, message, metadata
    ) values (
      'critical', 'registration', null,
      'Registration RPC failed — stranded auth account risk',
      SQLERRM,
      jsonb_build_object(
        'sqlstate',  SQLSTATE,
        'user_id',   p_user_id,
        'shop_name', p_shop_name,
        'email',     v_user_email
      )
    );
  exception when others then
    null; -- audit failure must never mask the original error
  end;

  -- Return success: false with the error so the audit row commits and
  -- the caller receives the exact error reason.
  return jsonb_build_object(
    'success', false,
    'error', SQLERRM
  );
end;
$$;

alter function public.register_new_shop_free_trial(
  uuid, text, text, text, text, text, text
) set search_path = public, pg_temp;


-- ── 2. get_registration_resume() ─────────────────────────────────────────────
-- Called by SplashScreen when a session exists but profileProvider is null.
-- Returns needs_resume=true + email when the auth user has no profile row.
create or replace function get_registration_resume()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id        uuid := auth.uid();
  v_email          text;
  v_profile_exists boolean;
begin
  if v_user_id is null then
    return jsonb_build_object('needs_resume', false);
  end if;

  select exists(select 1 from profiles where id = v_user_id)
  into v_profile_exists;

  if v_profile_exists then
    return jsonb_build_object('needs_resume', false);
  end if;

  select email into v_email from auth.users where id = v_user_id;

  return jsonb_build_object(
    'needs_resume', true,
    'email',        v_email,
    'user_id',      v_user_id
  );
exception when others then
  return jsonb_build_object('needs_resume', false);
end;
$$;

alter function public.get_registration_resume()
  set search_path = public, pg_temp;

grant execute on function public.get_registration_resume() to authenticated;
grant execute on function public.register_new_shop_free_trial(
  uuid, text, text, text, text, text, text
) to authenticated;
