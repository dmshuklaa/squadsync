-- ── Migration 009: Events, RSVP, and Event Roster ──────────────────────────
-- Creates three tables:
--   events        — scheduled games and training sessions
--   event_rsvps   — per-player RSVP responses
--   event_roster  — players confirmed on an event roster

-- ── Enums ────────────────────────────────────────────────────────────────────

DO $$ BEGIN
  CREATE TYPE event_type AS ENUM ('game', 'training');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE event_status AS ENUM ('scheduled', 'cancelled', 'completed');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE rsvp_status AS ENUM ('going', 'not_going', 'maybe');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── events ────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS events (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id       UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  created_by    UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title         TEXT NOT NULL,
  event_type    event_type NOT NULL DEFAULT 'training',
  status        event_status NOT NULL DEFAULT 'scheduled',
  starts_at     TIMESTAMPTZ NOT NULL,
  ends_at       TIMESTAMPTZ,
  location      TEXT,
  notes         TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS events_team_id_idx ON events(team_id);
CREATE INDEX IF NOT EXISTS events_starts_at_idx ON events(starts_at);
CREATE INDEX IF NOT EXISTS events_status_idx ON events(status);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_events_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS events_updated_at_trigger ON events;
CREATE TRIGGER events_updated_at_trigger
  BEFORE UPDATE ON events
  FOR EACH ROW EXECUTE FUNCTION update_events_updated_at();

-- ── event_rsvps ───────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS event_rsvps (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id      UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  profile_id    UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  status        rsvp_status NOT NULL,
  responded_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(event_id, profile_id)
);

CREATE INDEX IF NOT EXISTS event_rsvps_event_id_idx ON event_rsvps(event_id);
CREATE INDEX IF NOT EXISTS event_rsvps_profile_id_idx ON event_rsvps(profile_id);

-- ── event_roster ──────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS event_roster (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id      UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  profile_id    UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  is_fill_in    BOOLEAN NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(event_id, profile_id)
);

CREATE INDEX IF NOT EXISTS event_roster_event_id_idx ON event_roster(event_id);

-- ── RLS ───────────────────────────────────────────────────────────────────────

ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_rsvps ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_roster ENABLE ROW LEVEL SECURITY;

-- events: members of the team's club can SELECT
CREATE POLICY "events_select_club_members"
  ON events FOR SELECT
  USING (
    team_id IN (
      SELECT t.id FROM teams t
      JOIN divisions d ON d.id = t.division_id
      WHERE d.club_id = get_my_club_id()
    )
  );

-- events: club_admin and coach can INSERT
CREATE POLICY "events_insert_admins_coaches"
  ON events FOR INSERT
  WITH CHECK (
    (SELECT role FROM profiles WHERE id = auth.uid()) IN ('club_admin', 'coach')
    AND team_id IN (
      SELECT t.id FROM teams t
      JOIN divisions d ON d.id = t.division_id
      WHERE d.club_id = get_my_club_id()
    )
  );

-- events: creator, club_admin, or coach can UPDATE
CREATE POLICY "events_update_admins_coaches"
  ON events FOR UPDATE
  USING (
    created_by = auth.uid()
    OR (SELECT role FROM profiles WHERE id = auth.uid()) IN ('club_admin', 'coach')
  );

-- events: creator or club_admin can DELETE
CREATE POLICY "events_delete_admins"
  ON events FOR DELETE
  USING (
    created_by = auth.uid()
    OR (SELECT role FROM profiles WHERE id = auth.uid()) = 'club_admin'
  );

-- event_rsvps: club members can SELECT
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

-- event_rsvps: any authenticated user can upsert their own RSVP
CREATE POLICY "event_rsvps_upsert_own"
  ON event_rsvps FOR INSERT
  WITH CHECK (profile_id = auth.uid());

CREATE POLICY "event_rsvps_update_own"
  ON event_rsvps FOR UPDATE
  USING (profile_id = auth.uid());

CREATE POLICY "event_rsvps_delete_own"
  ON event_rsvps FOR DELETE
  USING (profile_id = auth.uid());

-- event_roster: club members can SELECT
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

-- event_roster: admins/coaches can INSERT/DELETE
CREATE POLICY "event_roster_insert_admins_coaches"
  ON event_roster FOR INSERT
  WITH CHECK (
    (SELECT role FROM profiles WHERE id = auth.uid()) IN ('club_admin', 'coach')
  );

CREATE POLICY "event_roster_delete_admins_coaches"
  ON event_roster FOR DELETE
  USING (
    (SELECT role FROM profiles WHERE id = auth.uid()) IN ('club_admin', 'coach')
  );
