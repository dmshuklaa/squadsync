-- Migration 007: Allow any authenticated user to read clubs by join code.
--
-- Problem: the existing clubs SELECT policy gates on get_my_club_id(), which
-- returns NULL for a brand-new user who has not yet joined a club. That means
-- the ilike('join_code', ...) lookup in joinClub() always returns NULL even
-- when the code is valid, causing every join attempt to throw ClubNotFoundException.
--
-- Fix: add an open SELECT policy for authenticated users. This is safe because:
--   • The user must be signed in (auth.uid() IS NOT NULL).
--   • Join codes are intentionally shareable — they are displayed to admins
--     specifically so they can be distributed.
--   • No financially sensitive or PII data is exposed by reading a club row.
--
-- Run this in the Supabase SQL Editor before testing the Join club flow.

CREATE POLICY "clubs_select_by_join_code"
  ON clubs FOR SELECT
  USING (auth.uid() IS NOT NULL);
