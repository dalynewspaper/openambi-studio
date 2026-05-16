-- Storage bucket + RLS for user-uploaded recording videos
-- Paths: {auth.uid()}/{recording_id}.{ext} inside bucket `user-recording-videos`.
--
-- Run in Supabase SQL Editor AFTER MIGRATION_VIDEO.sql.
--
-- Important: Supabase Storage may return HTTP **400** while the JSON body still
-- reports RLS (`"message":"new row violates row-level security policy"`). That
-- still means these policies (or a conflicting policy) rejected the insert.
--
-- Policies use `split_part(...)` on `name` instead of only `storage.foldername`,
-- which avoids evaluation quirks reported when foldername returns NULL in WITH
-- CHECK (see discussion around supabase/supabase#35157).

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
-- First folder segment of `name` must equal the authenticated user's id.

DROP POLICY IF EXISTS "Users upload own recording videos" ON storage.objects;
CREATE POLICY "Users upload own recording videos"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'user-recording-videos'
  AND auth.role() = 'authenticated'
  AND split_part(trim(both '/' from coalesce(name, '')), '/', 1) = auth.uid()::text
);

DROP POLICY IF EXISTS "Users update own recording videos" ON storage.objects;
CREATE POLICY "Users update own recording videos"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'user-recording-videos'
  AND split_part(trim(both '/' from coalesce(name, '')), '/', 1) = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'user-recording-videos'
  AND split_part(trim(both '/' from coalesce(name, '')), '/', 1) = auth.uid()::text
);

DROP POLICY IF EXISTS "Users delete own recording videos" ON storage.objects;
CREATE POLICY "Users delete own recording videos"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'user-recording-videos'
  AND split_part(trim(both '/' from coalesce(name, '')), '/', 1) = auth.uid()::text
);

DROP POLICY IF EXISTS "Public read recording videos" ON storage.objects;
CREATE POLICY "Public read recording videos"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'user-recording-videos');

-- 3) Verify
SELECT id, name, public, file_size_limit
FROM storage.buckets
WHERE id = 'user-recording-videos';

SELECT policyname, cmd, with_check
FROM pg_policies
WHERE schemaname = 'storage' AND tablename = 'objects'
  AND policyname LIKE '%recording videos%';
