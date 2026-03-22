-- Sprint 5: Match day selection, fill-in open mode, squad size settings

-- 1. Add selection_status to event_roster
ALTER TABLE event_roster
  ADD COLUMN IF NOT EXISTS selection_status TEXT NOT NULL DEFAULT 'selected'
    CHECK (selection_status IN ('selected', 'reserve', 'unavailable'));

-- 2. Add fill_in_mode to clubs
ALTER TABLE clubs
  ADD COLUMN IF NOT EXISTS fill_in_mode TEXT NOT NULL DEFAULT 'restricted'
    CHECK (fill_in_mode IN ('restricted', 'open'));

-- 3. Add squad size settings to teams
ALTER TABLE teams
  ADD COLUMN IF NOT EXISTS squad_size INTEGER,
  ADD COLUMN IF NOT EXISTS playing_xi_size INTEGER;

-- No RLS changes needed: event_roster, clubs, and teams already have
-- policies in place from earlier migrations.
