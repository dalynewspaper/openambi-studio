-- VERIFY AND FIX STORAGE BUCKET CONFIGURATION
-- User recordings need to be accessible for playback

-- Step 1: Check if user-recordings bucket exists and is public
SELECT 
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types
FROM storage.buckets
WHERE name = 'user-recordings';

-- Step 2: If bucket doesn't exist, create it (uncomment if needed)
-- INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
-- VALUES (
--     'user-recordings',
--     'user-recordings',
--     true,  -- Make it public so files can be accessed via /object/public/
--     52428800,  -- 50MB limit
--     ARRAY['audio/m4a', 'audio/mpeg', 'audio/mp4']
-- )
-- ON CONFLICT (name) DO NOTHING;

-- Step 3: Make sure the bucket is public (if it exists)
UPDATE storage.buckets
SET public = true
WHERE name = 'user-recordings';

-- Step 4: Verify storage policies allow public read access
SELECT 
    policyname,
    cmd,
    roles::text
FROM pg_policies
WHERE schemaname = 'storage' 
  AND tablename = 'objects'
  AND policyname LIKE '%user-recordings%';

-- Step 5: Create public read policy if it doesn't exist
DROP POLICY IF EXISTS "Public can read user-recordings" ON storage.objects;

CREATE POLICY "Public can read user-recordings"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'user-recordings');

-- Step 6: Verify final state
SELECT 
    'Bucket Public' as check_type,
    CASE WHEN public THEN 'YES' ELSE 'NO' END as status
FROM storage.buckets
WHERE name = 'user-recordings';

