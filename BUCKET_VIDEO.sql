-- Storage bucket + RLS for user-uploaded recording videos
-- Mirrors the posture of `user-recordings` (public read, per-user prefix
-- INSERT/UPDATE/DELETE). Paths: {auth.uid()}/{recording_id}.{ext}.
--
-- Uses `(storage.foldername(name))[1]` like CREATE_BUCKET.sql — matches how
-- Supabase stores object paths and avoids edge cases with `split_part`.
--
-- Run in Supabase SQL Editor AFTER MIGRATION_VIDEO.sql.
--
-- If uploads still fail with "row-level violates row-level security policy",
-- confirm these policies exist and were NOT removed by a broad cleanup
-- script that drops names matching `%recording%` (see FIX_STORAGE_RLS.sql).

-- 1) Create bucket (public read — same as audio)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'user-recording-videos',
  'user-recording-videos',
  true,
  524288000, -- 500 MB cap; tune via dashboard if needed
  ARRAY['video/mp4', 'video/quicktime', 'video/x-m4v']::text[]
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = COALESCE(EXCLUDED.file_size_limit, storage.buckets.file_size_limit),
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- 2) Policies on storage.objects

DROP POLICY IF EXISTS "Users upload own recording videos" ON storage.objects;
CREATE POLICY "Users upload own recording videos"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'user-recording-videos'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Users update own recording videos" ON storage.objects;
CREATE POLICY "Users update own recording videos"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'user-recording-videos'
  AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'user-recording-videos'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Users delete own recording videos" ON storage.objects;
CREATE POLICY "Users delete own recording videos"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'user-recording-videos'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Public read recording videos" ON storage.objects;
CREATE POLICY "Public read recording videos"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'user-recording-videos');

-- 3) Verify
SELECT id, name, public, file_size_limit
FROM storage.buckets
WHERE id = 'user-recording-videos';

SELECT policyname, cmd
FROM pg_policies
WHERE schemaname = 'storage' AND tablename = 'objects'
  AND policyname LIKE '%recording videos%';
