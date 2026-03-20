-- Sprint 4.2: Add FCM push token column to profiles

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS fcm_token TEXT;
