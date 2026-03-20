-- Sprint 4.2: Team chat messages

-- Ensure the updated_at trigger function exists (safe to re-create)
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE chat_messages (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id    UUID        NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  sender_id  UUID        NOT NULL REFERENCES profiles(id),
  content    TEXT        NOT NULL,
  edited     BOOLEAN     NOT NULL DEFAULT FALSE,
  deleted    BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_chat_team
  ON chat_messages(team_id);
CREATE INDEX idx_chat_created
  ON chat_messages(team_id, created_at DESC);
CREATE INDEX idx_chat_sender
  ON chat_messages(sender_id);

CREATE TRIGGER chat_updated_at
  BEFORE UPDATE ON chat_messages
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- Team members and club admins/coaches can read messages
CREATE POLICY "chat_select_member"
  ON chat_messages FOR SELECT
  USING (
    team_id IN (
      SELECT tm.team_id
      FROM team_memberships tm
      WHERE tm.profile_id = auth.uid()
        AND tm.status = 'active'
    )
    OR team_id IN (
      SELECT t.id FROM teams t
      JOIN divisions d ON d.id = t.division_id
      WHERE d.club_id = get_my_club_id()
    )
  );

-- Club members can insert messages for their club's teams
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

-- Sender can edit or soft-delete own messages
CREATE POLICY "chat_update_own"
  ON chat_messages FOR UPDATE
  USING (sender_id = auth.uid());
