-- ============================================================
-- SquadSync — Migration 002
-- Fix RLS infinite recursion on profiles table
-- ============================================================
--
-- Root cause: policies on clubs, divisions, teams, and
-- team_memberships used subqueries like:
--   SELECT club_id FROM profiles WHERE id = auth.uid()
-- When evaluated on the profiles table itself this causes
-- infinite recursion (PostgreSQL error 42P17).
--
-- Fix: a SECURITY DEFINER function get_my_club_id() that
-- bypasses RLS and returns the current user's club_id
-- directly. All affected policies are rewritten to call it.
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. SECURITY DEFINER HELPER
-- ────────────────────────────────────────────────────────────
-- Runs with elevated privileges so it can read profiles
-- without triggering the RLS policies on that table.
-- Safe: returns only the calling user's own club_id.

CREATE OR REPLACE FUNCTION get_my_club_id()
RETURNS UUID
LANGUAGE SQL
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT club_id FROM profiles WHERE id = auth.uid()
$$;

-- ────────────────────────────────────────────────────────────
-- 2. FIX PROFILES POLICY
-- ────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "profiles_select_same_club" ON profiles;

CREATE POLICY "profiles_select_same_club"
  ON profiles FOR SELECT
  USING (club_id = get_my_club_id());

-- ────────────────────────────────────────────────────────────
-- 3. FIX CLUBS POLICIES
-- ────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "clubs_select_member" ON clubs;
CREATE POLICY "clubs_select_member"
  ON clubs FOR SELECT
  USING (id = get_my_club_id());

DROP POLICY IF EXISTS "clubs_update_admin" ON clubs;
CREATE POLICY "clubs_update_admin"
  ON clubs FOR UPDATE
  USING (
    id = get_my_club_id()
    AND (SELECT role FROM profiles WHERE id = auth.uid()) = 'club_admin'
  );

-- ────────────────────────────────────────────────────────────
-- 4. FIX DIVISIONS POLICIES
-- ────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "divisions_select_member" ON divisions;
CREATE POLICY "divisions_select_member"
  ON divisions FOR SELECT
  USING (club_id = get_my_club_id());

DROP POLICY IF EXISTS "divisions_write_admin" ON divisions;
CREATE POLICY "divisions_write_admin"
  ON divisions FOR ALL
  USING (
    club_id = get_my_club_id()
    AND (SELECT role FROM profiles WHERE id = auth.uid()) = 'club_admin'
  );

-- ────────────────────────────────────────────────────────────
-- 5. FIX TEAMS POLICIES
-- ────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "teams_select_member" ON teams;
CREATE POLICY "teams_select_member"
  ON teams FOR SELECT
  USING (
    division_id IN (
      SELECT id FROM divisions WHERE club_id = get_my_club_id()
    )
  );

DROP POLICY IF EXISTS "teams_write_admin_coach" ON teams;
CREATE POLICY "teams_write_admin_coach"
  ON teams FOR ALL
  USING (
    division_id IN (
      SELECT id FROM divisions WHERE club_id = get_my_club_id()
    )
    AND (SELECT role FROM profiles WHERE id = auth.uid()) IN ('club_admin', 'coach')
  );

-- ────────────────────────────────────────────────────────────
-- 6. FIX TEAM MEMBERSHIPS POLICY
-- ────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "memberships_write_admin_coach" ON team_memberships;
CREATE POLICY "memberships_write_admin_coach"
  ON team_memberships FOR ALL
  USING (
    team_id IN (
      SELECT t.id FROM teams t
      JOIN divisions d ON d.id = t.division_id
      WHERE d.club_id = get_my_club_id()
    )
    AND (SELECT role FROM profiles WHERE id = auth.uid()) IN ('club_admin', 'coach')
  );

-- ============================================================
-- Phase 2: Fix clubs / divisions / teams INSERT policies
-- ============================================================
--
-- Root cause: clubs INSERT was blocked because get_my_club_id()
-- returns NULL for a brand-new user (they have no club_id yet).
-- The INSERT policy for clubs must not call get_my_club_id().
-- Division and team INSERT policies need explicit WITH CHECK
-- clauses to cover the window between profile update and the
-- subsequent inserts.
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 7. FIX CLUBS INSERT POLICY
-- ────────────────────────────────────────────────────────────
-- Any authenticated user can create a club. No club_id check
-- is valid here because the user has none yet.

DROP POLICY IF EXISTS "clubs_insert_authenticated" ON clubs;
CREATE POLICY "clubs_insert_authenticated"
  ON clubs FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- ────────────────────────────────────────────────────────────
-- 8. FIX PROFILES UPDATE POLICY
-- ────────────────────────────────────────────────────────────
-- Add explicit WITH CHECK so the update (setting club_id and
-- role) is permitted after club creation.

DROP POLICY IF EXISTS "profiles_update_own" ON profiles;
CREATE POLICY "profiles_update_own"
  ON profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- ────────────────────────────────────────────────────────────
-- 9. FIX DIVISIONS INSERT POLICY
-- ────────────────────────────────────────────────────────────
-- Allow club_admins to insert divisions. The OR condition
-- handles the window where get_my_club_id() already returns
-- the new club_id but the row's club_id is being validated.

DROP POLICY IF EXISTS "divisions_insert_admin" ON divisions;
CREATE POLICY "divisions_insert_admin"
  ON divisions FOR INSERT
  WITH CHECK (
    club_id = get_my_club_id()
    OR (SELECT role FROM profiles WHERE id = auth.uid()) = 'club_admin'
  );

-- ────────────────────────────────────────────────────────────
-- 10. FIX TEAMS INSERT POLICY
-- ────────────────────────────────────────────────────────────
-- Allow club_admins and coaches to insert teams directly by
-- role rather than requiring the division chain to resolve.

DROP POLICY IF EXISTS "teams_insert_admin_coach" ON teams;
CREATE POLICY "teams_insert_admin_coach"
  ON teams FOR INSERT
  WITH CHECK (
    (SELECT role FROM profiles WHERE id = auth.uid()) IN ('club_admin', 'coach')
  );
