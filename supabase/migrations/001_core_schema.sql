-- ============================================================
-- SquadSync — Core Schema Migration 001
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. ENUMS
-- ────────────────────────────────────────────────────────────

CREATE TYPE user_role AS ENUM (
  'club_admin', 'coach', 'player', 'parent'
);

CREATE TYPE membership_status AS ENUM (
  'active', 'inactive', 'archived', 'pending'
);

CREATE TYPE guardian_permission AS ENUM (
  'view', 'manage'
);

-- ────────────────────────────────────────────────────────────
-- 2. TABLES
-- ────────────────────────────────────────────────────────────

-- Clubs
CREATE TABLE clubs (
  id         UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
  name       TEXT      NOT NULL,
  sport_type TEXT      NOT NULL,
  join_code  CHAR(6)   NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Divisions
CREATE TABLE divisions (
  id              UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id         UUID      NOT NULL REFERENCES clubs(id) ON DELETE CASCADE,
  name            TEXT      NOT NULL,
  display_order   INTEGER   NOT NULL DEFAULT 0,
  fill_in_enabled BOOLEAN   NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Teams
CREATE TABLE teams (
  id          UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
  division_id UUID      NOT NULL REFERENCES divisions(id) ON DELETE CASCADE,
  name        TEXT      NOT NULL,
  season      TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Profiles (extends auth.users — same PK)
CREATE TABLE profiles (
  id                    UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name             TEXT        NOT NULL,
  phone                 TEXT,
  avatar_url            TEXT,
  role                  user_role   NOT NULL DEFAULT 'player',
  club_id               UUID        REFERENCES clubs(id) ON DELETE SET NULL,
  push_token            TEXT,
  availability_this_week BOOLEAN    NOT NULL DEFAULT TRUE,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Team memberships
CREATE TABLE team_memberships (
  id          UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id     UUID              NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  profile_id  UUID              NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  position    TEXT,
  jersey_number INTEGER,
  status      membership_status NOT NULL DEFAULT 'active',
  created_at  TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
  UNIQUE(team_id, profile_id)
);

-- Guardian links
CREATE TABLE guardian_links (
  id                  UUID                PRIMARY KEY DEFAULT gen_random_uuid(),
  player_profile_id   UUID                NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  guardian_profile_id UUID                NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  permission_level    guardian_permission NOT NULL DEFAULT 'view',
  confirmed           BOOLEAN             NOT NULL DEFAULT FALSE,
  created_at          TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
  UNIQUE(player_profile_id, guardian_profile_id)
);

-- ────────────────────────────────────────────────────────────
-- 3. INDEXES
-- ────────────────────────────────────────────────────────────

CREATE INDEX idx_divisions_club_id         ON divisions(club_id);
CREATE INDEX idx_teams_division_id         ON teams(division_id);
CREATE INDEX idx_profiles_club_id          ON profiles(club_id);
CREATE INDEX idx_team_memberships_team_id  ON team_memberships(team_id);
CREATE INDEX idx_team_memberships_profile_id ON team_memberships(profile_id);
CREATE INDEX idx_guardian_links_player     ON guardian_links(player_profile_id);
CREATE INDEX idx_guardian_links_guardian   ON guardian_links(guardian_profile_id);
CREATE INDEX idx_clubs_join_code           ON clubs(join_code);

-- ────────────────────────────────────────────────────────────
-- 4. UPDATED_AT TRIGGER
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER clubs_updated_at
  BEFORE UPDATE ON clubs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER team_memberships_updated_at
  BEFORE UPDATE ON team_memberships
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ────────────────────────────────────────────────────────────
-- 5. AUTO-CREATE PROFILE TRIGGER
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'New User'),
    COALESCE(
      (NEW.raw_user_meta_data->>'role')::user_role,
      'player'
    )
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ────────────────────────────────────────────────────────────
-- 6. JOIN CODE GENERATOR
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION generate_join_code()
RETURNS TEXT AS $$
DECLARE
  chars TEXT    := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code  TEXT    := '';
  i     INTEGER;
BEGIN
  FOR i IN 1..6 LOOP
    code := code || substr(
      chars,
      floor(random() * length(chars) + 1)::INTEGER,
      1
    );
  END LOOP;
  RETURN code;
END;
$$ LANGUAGE plpgsql;

-- ────────────────────────────────────────────────────────────
-- 7. ROW LEVEL SECURITY
-- ────────────────────────────────────────────────────────────

ALTER TABLE clubs            ENABLE ROW LEVEL SECURITY;
ALTER TABLE divisions        ENABLE ROW LEVEL SECURITY;
ALTER TABLE teams            ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles         ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE guardian_links   ENABLE ROW LEVEL SECURITY;

-- ── PROFILES ──────────────────────────────────────────────

-- Users can read their own profile
CREATE POLICY "profiles_select_own"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

-- Users in the same club can read each other's profiles
CREATE POLICY "profiles_select_same_club"
  ON profiles FOR SELECT
  USING (
    club_id IN (
      SELECT club_id FROM profiles WHERE id = auth.uid()
    )
  );

-- Users can update their own profile
CREATE POLICY "profiles_update_own"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

-- ── CLUBS ─────────────────────────────────────────────────

-- Club members can read their own club
CREATE POLICY "clubs_select_member"
  ON clubs FOR SELECT
  USING (
    id IN (
      SELECT club_id FROM profiles WHERE id = auth.uid()
    )
  );

-- Club admins can update their club
CREATE POLICY "clubs_update_admin"
  ON clubs FOR UPDATE
  USING (
    id IN (
      SELECT club_id FROM profiles
      WHERE id = auth.uid() AND role = 'club_admin'
    )
  );

-- Any authenticated user can insert a club (creating one)
CREATE POLICY "clubs_insert_authenticated"
  ON clubs FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- ── DIVISIONS ─────────────────────────────────────────────

-- Club members can read divisions in their club
CREATE POLICY "divisions_select_member"
  ON divisions FOR SELECT
  USING (
    club_id IN (
      SELECT club_id FROM profiles WHERE id = auth.uid()
    )
  );

-- Club admins can insert/update/delete divisions
CREATE POLICY "divisions_write_admin"
  ON divisions FOR ALL
  USING (
    club_id IN (
      SELECT club_id FROM profiles
      WHERE id = auth.uid() AND role = 'club_admin'
    )
  );

-- ── TEAMS ─────────────────────────────────────────────────

-- Club members can read teams in their club
CREATE POLICY "teams_select_member"
  ON teams FOR SELECT
  USING (
    division_id IN (
      SELECT d.id FROM divisions d
      JOIN profiles p ON p.club_id = d.club_id
      WHERE p.id = auth.uid()
    )
  );

-- Club admins and coaches can write teams
CREATE POLICY "teams_write_admin_coach"
  ON teams FOR ALL
  USING (
    division_id IN (
      SELECT d.id FROM divisions d
      JOIN profiles p ON p.club_id = d.club_id
      WHERE p.id = auth.uid()
        AND p.role IN ('club_admin', 'coach')
    )
  );

-- ── TEAM MEMBERSHIPS ──────────────────────────────────────

-- Members can read memberships for their team or their own record
CREATE POLICY "memberships_select_team_member"
  ON team_memberships FOR SELECT
  USING (
    team_id IN (
      SELECT team_id FROM team_memberships
      WHERE profile_id = auth.uid()
    )
    OR profile_id = auth.uid()
  );

-- Coaches and admins can write memberships
CREATE POLICY "memberships_write_admin_coach"
  ON team_memberships FOR ALL
  USING (
    team_id IN (
      SELECT tm.team_id
      FROM team_memberships tm
      JOIN profiles p ON p.id = auth.uid()
      WHERE p.role IN ('club_admin', 'coach')
    )
  );

-- ── GUARDIAN LINKS ────────────────────────────────────────

-- Guardians and players can read their own links
CREATE POLICY "guardian_links_select"
  ON guardian_links FOR SELECT
  USING (
    guardian_profile_id = auth.uid()
    OR player_profile_id = auth.uid()
  );

-- Club admins can read all guardian links in their club
CREATE POLICY "guardian_links_select_admin"
  ON guardian_links FOR SELECT
  USING (
    player_profile_id IN (
      SELECT p.id FROM profiles p
      JOIN profiles admin ON admin.club_id = p.club_id
      WHERE admin.id = auth.uid()
        AND admin.role = 'club_admin'
    )
  );

-- Authenticated users can create guardian link requests
CREATE POLICY "guardian_links_insert"
  ON guardian_links FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- Guardians can update (confirm/decline) their own links
CREATE POLICY "guardian_links_update"
  ON guardian_links FOR UPDATE
  USING (guardian_profile_id = auth.uid());
