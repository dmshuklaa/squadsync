-- 016_player_join_codes.sql
-- Adds per-player join codes to pending_players.
-- Adds default_availability and unavailable_dates to profiles.

-- Per-player join code on pending_players
ALTER TABLE pending_players
  ADD COLUMN IF NOT EXISTS join_code TEXT UNIQUE;

CREATE INDEX IF NOT EXISTS idx_pending_players_join_code
  ON pending_players(join_code);

-- Default availability on profiles
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS default_availability BOOLEAN NOT NULL DEFAULT TRUE;

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS unavailable_dates JSONB DEFAULT '[]';
