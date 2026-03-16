-- ============================================================
-- SquadSync — Migration 003
-- Fix team_memberships SELECT RLS infinite recursion
-- ============================================================
--
-- Root cause: "memberships_select_team_member" (from migration
-- 001) contains a self-referential subquery:
--
--   SELECT team_id FROM team_memberships
--   WHERE profile_id = auth.uid()
--
-- Querying team_memberships from inside a policy ON
-- team_memberships causes PostgreSQL error 42P17 (infinite
-- recursion). Migration 002 fixed the WRITE policy but did not
-- drop this broken SELECT policy.
--
-- Fix: drop the recursive SELECT policy and replace it with
-- one that uses get_my_club_id() (the SECURITY DEFINER helper
-- from migration 002) to resolve the club scope without
-- re-querying team_memberships.
-- ============================================================

-- Drop the recursive SELECT policy from migration 001
DROP POLICY IF EXISTS "memberships_select_team_member" ON team_memberships;
DROP POLICY IF EXISTS "memberships_select_same_club" ON team_memberships;

-- New SELECT policy: any club member can read memberships for
-- teams in their club. Covers club_admin, coach, player, parent.
-- Uses get_my_club_id() which is SECURITY DEFINER and safe from recursion.
CREATE POLICY "memberships_select_same_club"
  ON team_memberships FOR SELECT
  USING (
    team_id IN (
      SELECT t.id FROM teams t
      JOIN divisions d ON d.id = t.division_id
      WHERE d.club_id = get_my_club_id()
    )
  );
