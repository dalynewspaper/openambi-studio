-- Setup Storage Policies for Avatars Bucket
-- Run this in Supabase SQL Editor: https://supabase.com/dashboard → SQL Editor

-- Step 1: Verify the avatars bucket exists
SELECT 
    id, 
    name, 
    public, 
    file_size_limit,
    allowed_mime_types
FROM storage.buckets 
WHERE id = 'avatars';

-- Step 2: Drop existing policies for avatars bucket (if any)
-- Drop all possible policy names that might exist
DROP POLICY IF EXISTS "Authenticated users can upload avatars" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update avatars" ON storage.objects;
DROP POLICY IF EXISTS "Public can view avatars" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own avatar" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own avatar" ON storage.objects;

-- Step 3: Create INSERT policy - Allow authenticated users to upload their own avatar
-- Users can upload files where the filename starts with their user ID
-- Using case-insensitive matching (ILIKE) to handle UUID case differences
DROP POLICY IF EXISTS "Users can upload own avatar" ON storage.objects;
CREATE POLICY "Users can upload own avatar"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'avatars' AND
    -- Allow upload if filename starts with user ID (case-insensitive)
    -- Converts both to lowercase for comparison
    (LOWER(name) LIKE LOWER(auth.uid()::text) || '.%')
);

-- Step 4: Create UPDATE policy - Allow users to update their own avatar
DROP POLICY IF EXISTS "Users can update own avatar" ON storage.objects;
CREATE POLICY "Users can update own avatar"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'avatars' AND
    (LOWER(name) LIKE LOWER(auth.uid()::text) || '.%')
)
WITH CHECK (
    bucket_id = 'avatars' AND
    (LOWER(name) LIKE LOWER(auth.uid()::text) || '.%')
);

-- Step 5: Create SELECT policy - Public read access (since bucket is public)
-- This allows anyone to view avatars
DROP POLICY IF EXISTS "Public can view avatars" ON storage.objects;
CREATE POLICY "Public can view avatars"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'avatars');

-- Step 6: Create DELETE policy - Allow users to delete their own avatar
DROP POLICY IF EXISTS "Users can delete own avatar" ON storage.objects;
CREATE POLICY "Users can delete own avatar"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'avatars' AND
    (LOWER(name) LIKE LOWER(auth.uid()::text) || '.%')
);

-- Step 7: Verify policies were created
SELECT 
    policyname,
    cmd,
    roles::text,
    qual,
    with_check
FROM pg_policies
WHERE schemaname = 'storage' 
  AND tablename = 'objects'
  AND policyname LIKE '%avatar%';

-- Expected result: Should show 4 policies (INSERT, UPDATE, SELECT, DELETE)

