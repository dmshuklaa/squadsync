-- Table for players added manually before they have a Supabase account.
-- When they sign up via magic link their pending record gets merged into
-- their real profile by the application layer.

CREATE TABLE pending_players (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id      UUID        NOT NULL REFERENCES teams(id)    ON DELETE CASCADE,
  club_id      UUID        NOT NULL REFERENCES clubs(id)    ON DELETE CASCADE,
  full_name    TEXT        NOT NULL,
  email        TEXT        NOT NULL,
  phone        TEXT,
  position     TEXT,
  jersey_number INTEGER,
  invited_by   UUID        REFERENCES profiles(id),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (team_id, email)
);

-- RLS
ALTER TABLE pending_players ENABLE ROW LEVEL SECURITY;

-- Club admins and coaches can read pending players in their club
CREATE POLICY "pending_players_select"
  ON pending_players FOR SELECT
  USING (club_id = get_my_club_id());

-- Club admins and coaches can insert
CREATE POLICY "pending_players_insert"
  ON pending_players FOR INSERT
  WITH CHECK (
    club_id = get_my_club_id()
    AND (
      SELECT role FROM profiles WHERE id = auth.uid()
    ) IN ('club_admin', 'coach')
  );

-- Club admins and coaches can delete
CREATE POLICY "pending_players_delete"
  ON pending_players FOR DELETE
  USING (
    club_id = get_my_club_id()
    AND (
      SELECT role FROM profiles WHERE id = auth.uid()
    ) IN ('club_admin', 'coach')
  );

-- Indexes
CREATE INDEX idx_pending_players_team_id ON pending_players(team_id);
CREATE INDEX idx_pending_players_email   ON pending_players(email);
CREATE INDEX idx_pending_players_club_id ON pending_players(club_id);
