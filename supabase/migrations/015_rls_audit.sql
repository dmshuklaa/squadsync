-- ── Migration 015: Full RLS audit ────────────────────────────────────────────
--
-- Drops and recreates every RLS policy across all 15 tables.
-- Root cause fixed: event_roster was missing an UPDATE policy, silently
-- blocking selection_status updates for admins and coaches.
--
-- Security helper added: get_my_role() — SECURITY DEFINER so role lookups
-- inside policies never trigger recursive RLS on the profiles table.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── Role helper (SECURITY DEFINER — bypasses RLS on profiles) ────────────────

CREATE OR REPLACE FUNCTION get_my_role()
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT role::text FROM profiles WHERE id = auth.uid();
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- PROFILES
-- ─────────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "profiles_select_own"          ON profiles;
DROP POLICY IF EXISTS "profiles_select_same_club"    ON profiles;
DROP POLICY IF EXISTS "profiles_insert_own"          ON profiles;
DROP POLICY IF EXISTS "profiles_update_own"          ON profiles;
DROP POLICY IF EXISTS "profiles_select"              ON profiles;
DROP POLICY IF EXISTS "profiles_update"              ON profiles;

-- Any authenticated user can read profiles in their own club
CREATE POLICY "profiles_select_own"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "profiles_select_same_club"
  ON profiles FOR SELECT
  USING (club_id IS NOT NULL AND club_id = get_my_club_id());

-- Trigger-created row on signup
CREATE POLICY "profiles_insert_own"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Users can update their own profile only
CREATE POLICY "profiles_update_own"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

-- ─────────────────────────────────────────────────────────────────────────────
-- CLUBS
-- ─────────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "clubs_select_member"          ON clubs;
DROP POLICY IF EXISTS "clubs_select_by_join_code"    ON clubs;
DROP POLICY IF EXISTS "clubs_insert_authenticated"   ON clubs;
DROP POLICY IF EXISTS "clubs_update_admin"           ON clubs;

-- Members can read their own club
CREATE POLICY "clubs_select_member"
  ON clubs FOR SELECT
  USING (id = get_my_club_id());

-- Any authenticated user can look up a club by join code (needed for join flow)
CREATE POLICY "clubs_select_by_join_code"
  ON clubs FOR SELECT
  USING (auth.role() = 'authenticated');

-- Any authenticated user can create a club (onboarding)
CREATE POLICY "clubs_insert_authenticated"
  ON clubs FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- Only club_admin can update their club (name, sport_type, fill_in_mode, etc.)
CREATE POLICY "clubs_update_admin"
  ON clubs FOR UPDATE
  USING (
    id = get_my_club_id()
    AND get_my_role() = 'club_admin'
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- DIVISIONS
-- ─────────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "divisions_select_member"      ON divisions;
DROP POLICY IF EXISTS "divisions_write_admin"        ON divisions;
DROP POLICY IF EXISTS "divisions_insert_admin"       ON divisions;
DROP POLICY IF EXISTS "divisions_update_admin"       ON divisions;
DROP POLICY IF EXISTS "divisions_delete_admin"       ON divisions;

CREATE POLICY "divisions_select_member"
  ON divisions FOR SELECT
  USING (club_id = get_my_club_id());

CREATE POLICY "divisions_insert_admin"
  ON divisions FOR INSERT
  WITH CHECK (
    club_id = get_my_club_id()
    AND get_my_role() = 'club_admin'
  );

CREATE POLICY "divisions_update_admin"
  ON divisions FOR UPDATE
  USING (
    club_id = get_my_club_id()
    AND get_my_role() = 'club_admin'
  );

CREATE POLICY "divisions_delete_admin"
  ON divisions FOR DELETE
  USING (
    club_id = get_my_club_id()
    AND get_my_role() = 'club_admin'
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- TEAMS
-- ─────────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "teams_select_member"          ON teams;
DROP POLICY IF EXISTS "teams_write_admin_coach"      ON teams;
DROP POLICY IF EXISTS "teams_insert_admin_coach"     ON teams;
DROP POLICY IF EXISTS "teams_update_admin_coach"     ON teams;
DROP POLICY IF EXISTS "teams_delete_admin"           ON teams;

CREATE POLICY "teams_select_member"
  ON teams FOR SELECT
  USING (
    division_id IN (
      SELECT id FROM divisions WHERE club_id = get_my_club_id()
    )
  );

CREATE POLICY "teams_insert_admin_coach"
  ON teams FOR INSERT
  WITH CHECK (
    division_id IN (
      SELECT id FROM divisions WHERE club_id = get_my_club_id()
    )
    AND get_my_role() IN ('club_admin', 'coach')
  );

-- Includes squad_size / playing_xi_size updates (Sprint 5)
CREATE POLICY "teams_update_admin_coach"
  ON teams FOR UPDATE
  USING (
    division_id IN (
      SELECT id FROM divisions WHERE club_id = get_my_club_id()
    )
    AND get_my_role() IN ('club_admin', 'coach')
  );

CREATE POLICY "teams_delete_admin"
  ON teams FOR DELETE
  USING (
    division_id IN (
      SELECT id FROM divisions WHERE club_id = get_my_club_id()
    )
    AND get_my_role() = 'club_admin'
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- TEAM_MEMBERSHIPS
-- ─────────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "memberships_select_same_club"    ON team_memberships;
DROP POLICY IF EXISTS "memberships_write_admin_coach"   ON team_memberships;
DROP POLICY IF EXISTS "memberships_insert_admin_coach"  ON team_memberships;
DROP POLICY IF EXISTS "memberships_update_admin_coach"  ON team_memberships;
DROP POLICY IF EXISTS "memberships_delete_admin_coach"  ON team_memberships;

CREATE POLICY "memberships_select_same_club"
  ON team_memberships FOR SELECT
  USING (
    team_id IN (
      SELECT t.id FROM teams t
      JOIN divisions d ON d.id = t.division_id
      WHERE d.club_id = get_my_club_id()
    )
  );

CREATE POLICY "memberships_insert_admin_coach"
  ON team_memberships FOR INSERT
  WITH CHECK (
    get_my_role() IN ('club_admin', 'coach')
    AND team_id IN (
      SELECT t.id FROM teams t
      JOIN divisions d ON d.id = t.division_id
      WHERE d.club_id = get_my_club_id()
    )
  );

CREATE POLICY "memberships_update_admin_coach"
  ON team_memberships FOR UPDATE
  USING (
    get_my_role() IN ('club_admin', 'coach')
    AND team_id IN (
      SELECT t.id FROM teams t
      JOIN divisions d ON d.id = t.division_id
      WHERE d.club_id = get_my_club_id()
    )
  );

CREATE POLICY "memberships_delete_admin_coach"
  ON team_memberships FOR DELETE
  USING (
    get_my_role() IN ('club_admin', 'coach')
    AND team_id IN (
      SELECT t.id FROM teams t
      JOIN divisions d ON d.id = t.division_id
      WHERE d.club_id = get_my_club_id()
    )
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- PENDING_PLAYERS
-- ─────────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "pending_players_select"       ON pending_players;
DROP POLICY IF EXISTS "pending_players_insert"       ON pending_players;
DROP POLICY IF EXISTS "pending_players_update"       ON pending_players;
DROP POLICY IF EXISTS "pending_players_delete"       ON pending_players;

CREATE POLICY "pending_players_select"
  ON pending_players FOR SELECT
  USING (
    get_my_role() IN ('club_admin', 'coach')
    AND team_id IN (
      SELECT t.id FROM teams t
      JOIN divisions d ON d.id = t.division_id
      WHERE d.club_id = get_my_club_id()
    )
  );

CREATE POLICY "pending_players_insert"
  ON pending_players FOR INSERT
  WITH CHECK (
    get_my_role() IN ('club_admin', 'coach')
    AND team_id IN (
      SELECT t.id FROM teams t
      JOIN divisions d ON d.id = t.division_id
      WHERE d.club_id = get_my_club_id()
    )
  );

CREATE POLICY "pending_players_delete"
  ON pending_players FOR DELETE
  USING (
    get_my_role() IN ('club_admin', 'coach')
    AND team_id IN (
      SELECT t.id FROM teams t
      JOIN divisions d ON d.id = t.division_id
      WHERE d.club_id = get_my_club_id()
    )
  );

-- Pending players can also be deleted by any authenticated user matching
-- their own email (used in joinClub() to clean up shadow records)
CREATE POLICY "pending_players_delete_own_email"
  ON pending_players FOR DELETE
  USING (
    email = (SELECT email FROM profiles WHERE id = auth.uid())
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- GUARDIAN_LINKS
-- ─────────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "guardian_links_select"        ON guardian_links;
DROP POLICY IF EXISTS "guardian_links_select_admin"  ON guardian_links;
DROP POLICY IF EXISTS "guardian_links_insert_admin"  ON guardian_links;
DROP POLICY IF EXISTS "guardian_links_update"        ON guardian_links;
DROP POLICY IF EXISTS "guardian_links_delete"        ON guardian_links;

-- Guardian can see their links; player can see their links; admin/coach can see all in club
CREATE POLICY "guardian_links_select"
  ON guardian_links FOR SELECT
  USING (
    guardian_profile_id = auth.uid()
    OR player_profile_id = auth.uid()
    OR (
      get_my_role() IN ('club_admin', 'coach')
      AND player_profile_id IN (
        SELECT tm.profile_id FROM team_memberships tm
        JOIN teams t ON t.id = tm.team_id
        JOIN divisions d ON d.id = t.division_id
        WHERE d.club_id = get_my_club_id()
      )
    )
  );

-- Admin, coach, or the player themselves can request a guardian link
CREATE POLICY "guardian_links_insert"
  ON guardian_links FOR INSERT
  WITH CHECK (
    player_profile_id = auth.uid()
    OR get_my_role() IN ('club_admin', 'coach')
  );

-- Guardian confirms their own link; admin can also confirm
CREATE POLICY "guardian_links_update"
  ON guardian_links FOR UPDATE
  USING (
    guardian_profile_id = auth.uid()
    OR get_my_role() = 'club_admin'
  );

-- Guardian, player, or admin can remove a link
CREATE POLICY "guardian_links_delete"
  ON guardian_links FOR DELETE
  USING (
    guardian_profile_id = auth.uid()
    OR player_profile_id = auth.uid()
    OR get_my_role() = 'club_admin'
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- EVENTS
-- ─────────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "events_select_club_members"   ON events;
DROP POLICY IF EXISTS "events_insert_admins_coaches" ON events;
DROP POLICY IF EXISTS "events_update_admins_coaches" ON events;
DROP POLICY IF EXISTS "events_delete_admins"         ON events;

CREATE POLICY "events_select_club_members"
  ON events FOR SELECT
  USING (
    team_id IN (
      SELECT t.id FROM teams t
      JOIN divisions d ON d.id = t.division_id
      WHERE d.club_id = get_my_club_id()
    )
  );

CREATE POLICY "events_insert_admins_coaches"
  ON events FOR INSERT
  WITH CHECK (
    get_my_role() IN ('club_admin', 'coach')
    AND team_id IN (
      SELECT t.id FROM teams t
      JOIN divisions d ON d.id = t.division_id
      WHERE d.club_id = get_my_club_id()
    )
  );

CREATE POLICY "events_update_admins_coaches"
  ON events FOR UPDATE
  USING (
    created_by = auth.uid()
    OR (
      get_my_role() IN ('club_admin', 'coach')
      AND team_id IN (
        SELECT t.id FROM teams t
        JOIN divisions d ON d.id = t.division_id
        WHERE d.club_id = get_my_club_id()
      )
    )
  );

CREATE POLICY "events_delete_admins"
  ON events FOR DELETE
  USING (
    created_by = auth.uid()
    OR (
      get_my_role() = 'club_admin'
      AND team_id IN (
        SELECT t.id FROM teams t
        JOIN divisions d ON d.id = t.division_id
        WHERE d.club_id = get_my_club_id()
      )
    )
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT_RSVPS
-- ─────────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "event_rsvps_select_club_members" ON event_rsvps;
DROP POLICY IF EXISTS "event_rsvps_upsert_own"          ON event_rsvps;
DROP POLICY IF EXISTS "event_rsvps_update_own"          ON event_rsvps;
DROP POLICY IF EXISTS "event_rsvps_delete_own"          ON event_rsvps;

CREATE POLICY "event_rsvps_select_club_members"
  ON event_rsvps FOR SELECT
  USING (
    event_id IN (
      SELECT e.id FROM events e
      JOIN teams t ON t.id = e.team_id
      JOIN divisions d ON d.id = t.division_id
      WHERE d.club_id = get_my_club_id()
    )
  );

CREATE POLICY "event_rsvps_insert_own"
  ON event_rsvps FOR INSERT
  WITH CHECK (profile_id = auth.uid());

CREATE POLICY "event_rsvps_update_own"
  ON event_rsvps FOR UPDATE
  USING (profile_id = auth.uid());

CREATE POLICY "event_rsvps_delete_own"
  ON event_rsvps FOR DELETE
  USING (profile_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- EVENT_ROSTER
-- ─────────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "event_roster_select_club_members"  ON event_roster;
DROP POLICY IF EXISTS "event_roster_insert_admins_coaches" ON event_roster;
DROP POLICY IF EXISTS "event_roster_update_admins_coaches" ON event_roster;
DROP POLICY IF EXISTS "event_roster_delete_admins_coaches" ON event_roster;

CREATE POLICY "event_roster_select_club_members"
  ON event_roster FOR SELECT
  USING (
    event_id IN (
      SELECT e.id FROM events e
      JOIN teams t ON t.id = e.team_id
      JOIN divisions d ON d.id = t.division_id
      WHERE d.club_id = get_my_club_id()
    )
  );

CREATE POLICY "event_roster_insert_admins_coaches"
  ON event_roster FOR INSERT
  WITH CHECK (
    get_my_role() IN ('club_admin', 'coach')
    AND event_id IN (
      SELECT e.id FROM events e
      JOIN teams t ON t.id = e.team_id
      JOIN divisions d ON d.id = t.division_id
      WHERE d.club_id = get_my_club_id()
    )
  );

-- ── KEY FIX: admins and coaches can UPDATE (e.g. selection_status) ───────────
CREATE POLICY "event_roster_update_admins_coaches"
  ON event_roster FOR UPDATE
  USING (
    get_my_role() IN ('club_admin', 'coach')
    AND event_id IN (
      SELECT e.id FROM events e
      JOIN teams t ON t.id = e.team_id
      JOIN divisions d ON d.id = t.division_id
      WHERE d.club_id = get_my_club_id()
    )
  );

CREATE POLICY "event_roster_delete_admins_coaches"
  ON event_roster FOR DELETE
  USING (
    get_my_role() IN ('club_admin', 'coach')
    AND event_id IN (
      SELECT e.id FROM events e
      JOIN teams t ON t.id = e.team_id
      JOIN divisions d ON d.id = t.division_id
      WHERE d.club_id = get_my_club_id()
    )
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- FILL_IN_RULES
-- ─────────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "fill_in_rules_select"         ON fill_in_rules;
DROP POLICY IF EXISTS "fill_in_rules_write_admin"    ON fill_in_rules;
DROP POLICY IF EXISTS "fill_in_rules_insert_admin"   ON fill_in_rules;
DROP POLICY IF EXISTS "fill_in_rules_update_admin"   ON fill_in_rules;
DROP POLICY IF EXISTS "fill_in_rules_delete_admin"   ON fill_in_rules;

CREATE POLICY "fill_in_rules_select"
  ON fill_in_rules FOR SELECT
  USING (club_id = get_my_club_id());

CREATE POLICY "fill_in_rules_insert_admin"
  ON fill_in_rules FOR INSERT
  WITH CHECK (
    club_id = get_my_club_id()
    AND get_my_role() = 'club_admin'
  );

CREATE POLICY "fill_in_rules_update_admin"
  ON fill_in_rules FOR UPDATE
  USING (
    club_id = get_my_club_id()
    AND get_my_role() = 'club_admin'
  );

CREATE POLICY "fill_in_rules_delete_admin"
  ON fill_in_rules FOR DELETE
  USING (
    club_id = get_my_club_id()
    AND get_my_role() = 'club_admin'
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- FILL_IN_REQUESTS
-- ─────────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "fill_in_requests_select"      ON fill_in_requests;
DROP POLICY IF EXISTS "fill_in_requests_insert"      ON fill_in_requests;
DROP POLICY IF EXISTS "fill_in_requests_update"      ON fill_in_requests;

-- Player involved, requesting coach, or any admin/coach in the club can read
CREATE POLICY "fill_in_requests_select"
  ON fill_in_requests FOR SELECT
  USING (
    player_id = auth.uid()
    OR requesting_coach_id = auth.uid()
    OR (
      get_my_role() IN ('club_admin', 'coach')
      AND event_id IN (
        SELECT e.id FROM events e
        JOIN teams t ON t.id = e.team_id
        JOIN divisions d ON d.id = t.division_id
        WHERE d.club_id = get_my_club_id()
      )
    )
  );

-- Admin or coach can create a fill-in request
CREATE POLICY "fill_in_requests_insert"
  ON fill_in_requests FOR INSERT
  WITH CHECK (
    requesting_coach_id = auth.uid()
    AND get_my_role() IN ('club_admin', 'coach')
  );

-- Player responds; coach or admin can also update (e.g. cancel)
CREATE POLICY "fill_in_requests_update"
  ON fill_in_requests FOR UPDATE
  USING (
    player_id = auth.uid()
    OR requesting_coach_id = auth.uid()
    OR get_my_role() IN ('club_admin', 'coach')
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- FILL_IN_LOG
-- ─────────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "fill_in_log_select"           ON fill_in_log;
DROP POLICY IF EXISTS "fill_in_log_insert"           ON fill_in_log;

-- Player in the log, or any admin/coach in the same club can read
CREATE POLICY "fill_in_log_select"
  ON fill_in_log FOR SELECT
  USING (
    player_id = auth.uid()
    OR (
      get_my_role() IN ('club_admin', 'coach')
      AND event_id IN (
        SELECT e.id FROM events e
        JOIN teams t ON t.id = e.team_id
        JOIN divisions d ON d.id = t.division_id
        WHERE d.club_id = get_my_club_id()
      )
    )
  );

-- Any authenticated user can insert audit log entries (system-generated)
CREATE POLICY "fill_in_log_insert"
  ON fill_in_log FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- ─────────────────────────────────────────────────────────────────────────────
-- NOTIFICATIONS
-- ─────────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "notifications_select_own"     ON notifications;
DROP POLICY IF EXISTS "notifications_insert"         ON notifications;
DROP POLICY IF EXISTS "notifications_update_own"     ON notifications;
DROP POLICY IF EXISTS "notifications_delete_own"     ON notifications;

CREATE POLICY "notifications_select_own"
  ON notifications FOR SELECT
  USING (profile_id = auth.uid());

-- Any authenticated user can create notifications (app and edge functions)
CREATE POLICY "notifications_insert"
  ON notifications FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "notifications_update_own"
  ON notifications FOR UPDATE
  USING (profile_id = auth.uid());

CREATE POLICY "notifications_delete_own"
  ON notifications FOR DELETE
  USING (profile_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- CHAT_MESSAGES
-- ─────────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "chat_select_member"           ON chat_messages;
DROP POLICY IF EXISTS "chat_insert_member"           ON chat_messages;
DROP POLICY IF EXISTS "chat_update_own"              ON chat_messages;
DROP POLICY IF EXISTS "chat_delete_own"              ON chat_messages;

-- Active team members, admins, and coaches can read messages
CREATE POLICY "chat_select_member"
  ON chat_messages FOR SELECT
  USING (
    team_id IN (
      SELECT tm.team_id FROM team_memberships tm
      WHERE tm.profile_id = auth.uid() AND tm.status = 'active'
    )
    OR (
      get_my_role() IN ('club_admin', 'coach')
      AND team_id IN (
        SELECT t.id FROM teams t
        JOIN divisions d ON d.id = t.division_id
        WHERE d.club_id = get_my_club_id()
      )
    )
  );

-- Any club member can send messages (sender_id must be themselves)
CREATE POLICY "chat_insert_member"
  ON chat_messages FOR INSERT
  WITH CHECK (
    sender_id = auth.uid()
    AND team_id IN (
      SELECT t.id FROM teams t
      JOIN divisions d ON d.id = t.division_id
      WHERE d.club_id = get_my_club_id()
    )
  );

-- Sender can edit or soft-delete their own messages
CREATE POLICY "chat_update_own"
  ON chat_messages FOR UPDATE
  USING (sender_id = auth.uid());

-- Hard delete: sender or admin only (app uses soft delete; this is a safety valve)
CREATE POLICY "chat_delete_own"
  ON chat_messages FOR DELETE
  USING (
    sender_id = auth.uid()
    OR get_my_role() = 'club_admin'
  );

-- ── Reload PostgREST schema cache ─────────────────────────────────────────────
NOTIFY pgrst, 'reload schema';
