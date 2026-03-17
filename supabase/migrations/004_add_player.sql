-- ============================================================
-- SquadSync — Migration 004
-- Add player: email column, RLS insert policies
-- ============================================================
--
-- Changes:
-- 1. Add email column to profiles (denormalised from auth.users
--    for easy lookup without admin API access)
-- 2. Update handle_new_user() trigger to populate email
-- 3. Add team_memberships INSERT policy for admins/coaches
-- 4. Add profiles INSERT policy for own row (magic link signup)
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. ADD EMAIL COLUMN TO PROFILES
-- ────────────────────────────────────────────────────────────
-- Nullable so existing profiles (pre-migration) are unaffected.
-- Partial unique index allows multiple NULL values but enforces
-- uniqueness when email IS set.

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS email TEXT;

DROP INDEX IF EXISTS profiles_email_unique;
CREATE UNIQUE INDEX profiles_email_unique
  ON profiles(email)
  WHERE email IS NOT NULL;

-- ────────────────────────────────────────────────────────────
-- 2. UPDATE handle_new_user() TO POPULATE EMAIL
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'New User'),
    COALESCE(
      (NEW.raw_user_meta_data->>'role')::public.user_role,
      'player'
    ),
    NEW.email
  );
  RETURN NEW;
END;
$$;

-- ────────────────────────────────────────────────────────────
-- 3. TEAM_MEMBERSHIPS INSERT POLICY
-- ────────────────────────────────────────────────────────────
-- Allow club_admin and coach to add players to teams in their club.

DROP POLICY IF EXISTS "memberships_insert_admin_coach" ON team_memberships;

CREATE POLICY "memberships_insert_admin_coach"
  ON team_memberships FOR INSERT
  WITH CHECK (
    team_id IN (
      SELECT t.id FROM teams t
      JOIN divisions d ON d.id = t.division_id
      WHERE d.club_id = get_my_club_id()
    )
    AND (
      SELECT role FROM profiles WHERE id = auth.uid()
    ) IN ('club_admin', 'coach')
  );

-- ────────────────────────────────────────────────────────────
-- 4. PROFILES INSERT POLICY
-- ────────────────────────────────────────────────────────────
-- Allow an authenticated user to insert their own profile row.
-- Needed for invited users completing signup via magic link
-- (edge case where trigger didn't fire or was rolled back).

DROP POLICY IF EXISTS "profiles_insert_own" ON profiles;

CREATE POLICY "profiles_insert_own"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);
