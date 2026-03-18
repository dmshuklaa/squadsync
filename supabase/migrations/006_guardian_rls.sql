-- Migration 006: Guardian links RLS policies
-- Run in Supabase SQL Editor before testing the guardian linking flow.

-- Allow coaches, admins and the guardian themselves to view guardian links
-- for players in their club.
DROP POLICY IF EXISTS "guardian_links_select_admin" ON guardian_links;

CREATE POLICY "guardian_links_select_admin"
  ON guardian_links FOR SELECT
  USING (
    guardian_profile_id = auth.uid()
    OR player_profile_id IN (
      SELECT tm.profile_id
      FROM team_memberships tm
      JOIN teams t ON t.id = tm.team_id
      JOIN divisions d ON d.id = t.division_id
      WHERE d.club_id = get_my_club_id()
    )
  );

-- Allow admins, coaches and the player themselves to insert guardian link requests.
DROP POLICY IF EXISTS "guardian_links_insert_admin" ON guardian_links;

CREATE POLICY "guardian_links_insert_admin"
  ON guardian_links FOR INSERT
  WITH CHECK (
    (
      SELECT role FROM profiles
      WHERE id = auth.uid()
    ) IN ('club_admin', 'coach')
    OR auth.uid() = player_profile_id
  );

-- Allow the guardian or a club admin to update (confirm) links.
DROP POLICY IF EXISTS "guardian_links_update" ON guardian_links;

CREATE POLICY "guardian_links_update"
  ON guardian_links FOR UPDATE
  USING (
    guardian_profile_id = auth.uid()
    OR (
      SELECT role FROM profiles
      WHERE id = auth.uid()
    ) = 'club_admin'
  );

-- Allow the guardian or a club admin to delete (decline/remove) links.
DROP POLICY IF EXISTS "guardian_links_delete" ON guardian_links;

CREATE POLICY "guardian_links_delete"
  ON guardian_links FOR DELETE
  USING (
    guardian_profile_id = auth.uid()
    OR (
      SELECT role FROM profiles
      WHERE id = auth.uid()
    ) = 'club_admin'
  );
