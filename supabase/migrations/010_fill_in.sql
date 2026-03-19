-- 010_fill_in.sql — Cross-division fill-in request system

CREATE TYPE fill_in_request_status AS ENUM (
  'pending', 'accepted', 'declined', 'expired', 'cancelled'
);

CREATE TABLE fill_in_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id UUID NOT NULL REFERENCES clubs(id) ON DELETE CASCADE,
  source_division_id UUID NOT NULL REFERENCES divisions(id) ON DELETE CASCADE,
  target_division_id UUID NOT NULL REFERENCES divisions(id) ON DELETE CASCADE,
  min_age INTEGER,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(club_id, source_division_id, target_division_id)
);

CREATE TABLE fill_in_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  requesting_coach_id UUID NOT NULL REFERENCES profiles(id),
  player_id UUID NOT NULL REFERENCES profiles(id),
  position_needed TEXT,
  status fill_in_request_status NOT NULL DEFAULT 'pending',
  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  responded_at TIMESTAMPTZ,
  UNIQUE(event_id, player_id)
);

CREATE TABLE fill_in_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fill_in_request_id UUID REFERENCES fill_in_requests(id),
  player_id UUID NOT NULL REFERENCES profiles(id),
  home_division_id UUID NOT NULL REFERENCES divisions(id),
  target_division_id UUID NOT NULL REFERENCES divisions(id),
  event_id UUID NOT NULL REFERENCES events(id),
  event_date DATE NOT NULL,
  game_name TEXT NOT NULL,
  outcome TEXT NOT NULL DEFAULT 'played',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_fill_in_rules_club ON fill_in_rules(club_id);
CREATE INDEX idx_fill_in_requests_event ON fill_in_requests(event_id);
CREATE INDEX idx_fill_in_requests_player ON fill_in_requests(player_id);
CREATE INDEX idx_fill_in_requests_status ON fill_in_requests(status);
CREATE INDEX idx_fill_in_log_player ON fill_in_log(player_id);
CREATE INDEX idx_fill_in_log_event ON fill_in_log(event_id);

-- RLS
ALTER TABLE fill_in_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE fill_in_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE fill_in_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "fill_in_rules_select"
  ON fill_in_rules FOR SELECT
  USING (club_id = get_my_club_id());

CREATE POLICY "fill_in_rules_write_admin"
  ON fill_in_rules FOR ALL
  USING (
    club_id = get_my_club_id()
    AND (SELECT role FROM profiles WHERE id = auth.uid()) = 'club_admin'
  );

CREATE POLICY "fill_in_requests_select"
  ON fill_in_requests FOR SELECT
  USING (
    requesting_coach_id = auth.uid()
    OR player_id = auth.uid()
    OR (
      (SELECT role FROM profiles WHERE id = auth.uid()) IN ('club_admin', 'coach')
      AND event_id IN (
        SELECT e.id FROM events e
        JOIN teams t ON t.id = e.team_id
        JOIN divisions d ON d.id = t.division_id
        WHERE d.club_id = get_my_club_id()
      )
    )
  );

CREATE POLICY "fill_in_requests_insert"
  ON fill_in_requests FOR INSERT
  WITH CHECK (
    requesting_coach_id = auth.uid()
    AND (SELECT role FROM profiles WHERE id = auth.uid()) IN ('club_admin', 'coach')
  );

CREATE POLICY "fill_in_requests_update"
  ON fill_in_requests FOR UPDATE
  USING (
    player_id = auth.uid()
    OR requesting_coach_id = auth.uid()
  );

CREATE POLICY "fill_in_log_select"
  ON fill_in_log FOR SELECT
  USING (
    player_id = auth.uid()
    OR (
      (SELECT role FROM profiles WHERE id = auth.uid()) IN ('club_admin', 'coach')
      AND target_division_id IN (
        SELECT d.id FROM divisions d WHERE d.club_id = get_my_club_id()
      )
    )
  );

CREATE POLICY "fill_in_log_insert"
  ON fill_in_log FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);
