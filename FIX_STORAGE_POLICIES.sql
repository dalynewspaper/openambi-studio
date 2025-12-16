-- FIX STORAGE POLICIES
-- The error is coming from storage upload, not database insert
-- This suggests storage bucket policies are blocking the upload

-- Step 1: Check current storage policies
SELECT 
    'Storage Policies' as check_type,
    COUNT(*) as count
FROM storage.policies
WHERE bucket_id = 'user-recordings';

-- Step 2: Drop all existing policies on user-recordings bucket
DROP POLICY IF EXISTS "Users can upload own recordings" ON storage.objects;
DROP POLICY IF EXISTS "Users can view own recordings" ON storage.objects;
DROP POLICY IF EXISTS "Public Access" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload" ON storage.objects;

-- Step 3: Create permissive upload policy
-- Allow authenticated users to upload to their own folder
CREATE POLICY "Authenticated users can upload to own folder"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'user-recordings' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Step 4: Create permissive select policy (for downloading)
CREATE POLICY "Users can view own recordings"
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'user-recordings' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Step 5: Allow public read access (if you want recordings to be publicly accessible)
-- Uncomment if needed:
-- CREATE POLICY "Public can view recordings"
-- ON storage.objects
-- FOR SELECT
-- TO public
-- USING (bucket_id = 'user-recordings');

-- Step 6: Verify policies
SELECT 
    policyname,
    cmd,
    roles,
    qual,
    with_check
FROM pg_policies
WHERE schemaname = 'storage' 
  AND tablename = 'objects'
  AND policyname LIKE '%user-recordings%' OR policyname LIKE '%recording%';

-- Alternative: If policies don't work, try disabling RLS on storage.objects
-- (Not recommended for production, but useful for testing)
-- ALTER TABLE storage.objects DISABLE ROW LEVEL SECURITY;

