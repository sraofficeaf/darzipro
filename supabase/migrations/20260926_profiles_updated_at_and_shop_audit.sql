-- Migration: 20260926_profiles_updated_at_and_shop_audit.sql
-- Purpose:
-- 1. Add updated_at column to profiles with auto-updating trigger
-- 2. Backfill updated_at from created_at
-- 3. Create dedicated profile_shop_audit_history table and trigger for shop_id changes
-- 4. Also insert into admin_audit_logs whenever a profile's shop_id changes

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

-- 4. Audit trail table for shop_id changes
CREATE TABLE IF NOT EXISTS public.profile_shop_audit_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL,
  old_shop_id uuid,
  new_shop_id uuid,
  changed_by text,
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

-- 5. Trigger function to audit profile shop_id repointing
CREATE OR REPLACE FUNCTION public.handle_profiles_shop_change_audit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_actor text;
BEGIN
  IF OLD.shop_id IS DISTINCT FROM NEW.shop_id THEN
    v_actor := COALESCE(auth.jwt() ->> 'email', current_user);
    
    -- Insert into dedicated history table
    INSERT INTO public.profile_shop_audit_history (
      profile_id,
      old_shop_id,
      new_shop_id,
      changed_by,
      changed_at
    ) VALUES (
      NEW.id,
      OLD.shop_id,
      NEW.shop_id,
      v_actor,
      now()
    );

    -- Also insert into admin_audit_logs
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
      'warning',
      'security',
      NEW.shop_id,
      'Profile Shop Repointed',
      'Profile ' || NEW.id || ' shop_id changed from ' || COALESCE(OLD.shop_id::text, 'null') || ' to ' || COALESCE(NEW.shop_id::text, 'null') || ' by ' || v_actor,
      jsonb_build_object(
        'profile_id', NEW.id,
        'old_shop_id', OLD.shop_id,
        'new_shop_id', NEW.shop_id,
        'changed_by', v_actor,
        'changed_at', now()
      ),
      false,
      now()
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_profiles_shop_change_audit ON public.profiles;
CREATE TRIGGER trg_profiles_shop_change_audit
AFTER UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.handle_profiles_shop_change_audit();
