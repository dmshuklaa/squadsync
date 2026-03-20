-- ── Sprint 4: Notifications ─────────────────────────────────────────────────

CREATE TYPE notification_type AS ENUM (
  'fill_in_request',
  'fill_in_accepted',
  'fill_in_declined',
  'guardian_request',
  'guardian_accepted',
  'event_reminder',
  'general'
);

CREATE TABLE notifications (
  id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID         NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type       notification_type NOT NULL,
  title      TEXT         NOT NULL,
  body       TEXT         NOT NULL,
  data       JSONB        NOT NULL DEFAULT '{}',
  read       BOOLEAN      NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_profile
  ON notifications(profile_id);
CREATE INDEX idx_notifications_read
  ON notifications(profile_id, read);
CREATE INDEX idx_notifications_created
  ON notifications(created_at DESC);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notifications_select_own"
  ON notifications FOR SELECT
  USING (profile_id = auth.uid());

CREATE POLICY "notifications_update_own"
  ON notifications FOR UPDATE
  USING (profile_id = auth.uid());

CREATE POLICY "notifications_insert"
  ON notifications FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);
