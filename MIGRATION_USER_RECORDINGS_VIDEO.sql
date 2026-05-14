-- Migration: optional video path on user_recordings (launch video backgrounds)
-- Run in Supabase SQL Editor AFTER backup / staging verification.
-- Companion: RPC_LAUNCH_VIDEO_USER_RECORDINGS.sql, SETUP_USER_RECORDING_VIDEOS_BUCKET.sql
-- Spec: TECH_SPEC_LAUNCH_VIDEO_COMPOSITION.md

-- Phase A: storage path only (client builds public URL like audio)
ALTER TABLE user_recordings
  ADD COLUMN IF NOT EXISTS video_file_path TEXT NULL;

COMMENT ON COLUMN user_recordings.video_file_path IS
  'Path in user-recording-videos bucket: {user_id}/{recording_id}.ext';

-- Phase B (optional — uncomment when implementing alignment tools):
-- ALTER TABLE user_recordings
--   ADD COLUMN IF NOT EXISTS audio_trim_start_seconds DOUBLE PRECISION NULL;
-- ALTER TABLE user_recordings
--   ADD COLUMN IF NOT EXISTS audio_trim_end_seconds DOUBLE PRECISION NULL;
-- ALTER TABLE user_recordings
--   ADD COLUMN IF NOT EXISTS video_offset_ms INTEGER NULL;

-- Verify
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'user_recordings'
  AND column_name IN ('video_file_path');
