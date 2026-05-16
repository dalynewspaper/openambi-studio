-- Migration: optional video path on user_recordings
-- Adds a nullable storage path so a recording can carry an immersive
-- background video alongside its audio. Mirrors how `file_path` is used
-- for audio — the iOS client builds the public URL itself.
--
-- Run in Supabase SQL Editor BEFORE BUCKET_VIDEO.sql and RPC_VIDEO.sql.

ALTER TABLE user_recordings
  ADD COLUMN IF NOT EXISTS video_file_path TEXT NULL;

COMMENT ON COLUMN user_recordings.video_file_path IS
  'Path in user-recording-videos bucket: {user_id}/{recording_id}.{ext}';

-- Verify
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'user_recordings'
  AND column_name = 'video_file_path';
