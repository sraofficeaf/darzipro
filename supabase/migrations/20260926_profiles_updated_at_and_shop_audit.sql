-- Migration: 20260926_profiles_updated_at_and_shop_audit.sql
-- Purpose:
-- 1. Add updated_at column to profiles with auto-updating trigger
-- 2. Backfill updated_at from created_at
-- 3. Create dedicated profile_shop_audit_history table with distinct actor_email and db_role columns
-- 4. Audit trail triggers for INSERT, UPDATE, and DELETE on profiles table
-- 5. Mirror audit events into admin_audit_logs

-- 1. Add updated_at to profiles
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

-- 2. Backfill existing rows from created_at
UPDATE public.profiles
SET updated_at = created_at
WHERE updated_at IS NOT NULL;

-- 3. Trigger function to maintain profiles.updated_at
CREATE OR REPLACE FUNCTION public.handle_profiles_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_profiles_updated_at ON public.profiles;
CREATE TRIGGER trg_profiles_updated_at
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.handle_profiles_updated_at();

-- 4. Audit trail table for shop_id changes with separated actor_email and db_role
CREATE TABLE IF NOT EXISTS public.profile_shop_audit_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL,
  action text NOT NULL DEFAULT 'UPDATE',
  old_shop_id uuid,
  new_shop_id uuid,
  actor_email text,
  db_role text NOT NULL DEFAULT current_user,
  changed_at timestamptz NOT NULL DEFAULT now()
);

-- RLS on profile_shop_audit_history
ALTER TABLE public.profile_shop_audit_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS profile_shop_audit_history_admin_select ON public.profile_shop_audit_history;
CREATE POLICY profile_shop_audit_history_admin_select ON public.profile_shop_audit_history
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.admin_users
    WHERE admin_users.email = (auth.jwt() ->> 'email')
      AND (admin_users.role = 'superadmin' OR admin_users.role = 'admin')
  )
);

-- 5. Trigger function to audit profile shop_id INSERT, UPDATE, and DELETE
CREATE OR REPLACE FUNCTION public.handle_profiles_shop_change_audit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor_email text;
  v_db_role     text;
  v_action      text;
  v_profile_id  uuid;
  v_old_shop_id uuid;
  v_new_shop_id uuid;
BEGIN
  v_actor_email := (auth.jwt() ->> 'email');
  v_db_role     := current_user;

  IF (TG_OP = 'INSERT') THEN
    v_action      := 'INSERT';
    v_profile_id  := NEW.id;
    v_old_shop_id := NULL;
    v_new_shop_id := NEW.shop_id;
  ELSIF (TG_OP = 'UPDATE') THEN
    IF OLD.shop_id IS NOT DISTINCT FROM NEW.shop_id THEN
      RETURN NEW; -- No shop change
    END IF;
    v_action      := 'UPDATE';
    v_profile_id  := NEW.id;
    v_old_shop_id := OLD.shop_id;
    v_new_shop_id := NEW.shop_id;
  ELSIF (TG_OP = 'DELETE') THEN
    v_action      := 'DELETE';
    v_profile_id  := OLD.id;
    v_old_shop_id := OLD.shop_id;
    v_new_shop_id := NULL;
  END IF;

  -- 1. Insert into dedicated history table with separate actor_email and db_role
  INSERT INTO public.profile_shop_audit_history (
    profile_id,
    action,
    old_shop_id,
    new_shop_id,
    actor_email,
    db_role,
    changed_at
  ) VALUES (
    v_profile_id,
    v_action,
    v_old_shop_id,
    v_new_shop_id,
    v_actor_email,
    v_db_role,
    now()
  );

  -- 2. Insert into admin_audit_logs
  INSERT INTO public.admin_audit_logs (
    severity,
    category,
    shop_id,
    title,
    message,
    metadata,
    is_resolved,
    created_at
  ) VALUES (
    CASE WHEN v_action = 'DELETE' THEN 'critical' ELSE 'warning' END,
    'security',
    COALESCE(v_new_shop_id, v_old_shop_id),
    'Profile Shop ' || v_action,
    'Profile ' || v_profile_id || ' ' || v_action || ' (shop: ' || COALESCE(v_old_shop_id::text, 'null') || ' -> ' || COALESCE(v_new_shop_id::text, 'null') || ') by actor_email: ' || COALESCE(v_actor_email, 'no-jwt') || ' [db_role: ' || v_db_role || ']',
    jsonb_build_object(
      'profile_id',  v_profile_id,
      'action',      v_action,
      'old_shop_id', v_old_shop_id,
      'new_shop_id', v_new_shop_id,
      'actor_email', v_actor_email,
      'db_role',     v_db_role,
      'changed_at',  now()
    ),
    false,
    now()
  );

  IF (TG_OP = 'DELETE') THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$;

DROP TRIGGER IF EXISTS trg_profiles_shop_change_audit ON public.profiles;
CREATE TRIGGER trg_profiles_shop_change_audit
AFTER INSERT OR UPDATE OR DELETE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.handle_profiles_shop_change_audit();
