-- FIX STORAGE RLS ISSUE
-- The error "new row violates row-level security policy" during file upload
-- suggests the storage.objects table has RLS enabled and is blocking inserts

-- Step 1: Check if storage.objects has RLS enabled
SELECT 
    'storage.objects RLS' as check_type,
    CASE WHEN rowsecurity THEN 'ENABLED' ELSE 'DISABLED' END as status
FROM pg_tables
WHERE schemaname = 'storage' AND tablename = 'objects';

-- Step 2: Check existing policies on storage.objects
SELECT 
    policyname,
    cmd,
    roles::text,
    qual,
    with_check
FROM pg_policies
WHERE schemaname = 'storage' AND tablename = 'objects';

-- Step 3: Drop all existing policies on storage.objects for user-recordings bucket
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE schemaname = 'storage' 
          AND tablename = 'objects'
          AND (policyname LIKE '%user-recordings%' 
               OR policyname LIKE '%recording%'
               OR policyname LIKE '%upload%')
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', r.policyname);
        RAISE NOTICE 'Dropped policy: %', r.policyname;
    END LOOP;
END $$;

-- Step 4: Drop existing policies (if they exist) before creating new ones
DROP POLICY IF EXISTS "Authenticated users can upload to user-recordings" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can view user-recordings" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update own recordings" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete own recordings" ON storage.objects;

-- Step 5: Create permissive INSERT policy for authenticated users
-- This allows authenticated users to upload files to the user-recordings bucket
CREATE POLICY "Authenticated users can upload to user-recordings"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'user-recordings'
);

-- Step 6: Create permissive SELECT policy for authenticated users
-- This allows authenticated users to view files in the user-recordings bucket
CREATE POLICY "Authenticated users can view user-recordings"
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'user-recordings'
);

-- Step 7: Create UPDATE policy (if needed for overwriting files)
CREATE POLICY "Authenticated users can update own recordings"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'user-recordings' AND
    (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
    bucket_id = 'user-recordings' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Step 8: Create DELETE policy (if needed)
CREATE POLICY "Authenticated users can delete own recordings"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'user-recordings' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Step 9: Verify final state
SELECT 
    'Final Policy Count' as check_type,
    COUNT(*)::text as count
FROM pg_policies
WHERE schemaname = 'storage' AND tablename = 'objects';

-- Step 10: If still having issues, you can temporarily disable RLS on storage.objects
-- (Only for testing - NOT recommended for production)
-- ALTER TABLE storage.objects DISABLE ROW LEVEL SECURITY;

-- Note: After running this, try uploading again. The storage upload should work now.

