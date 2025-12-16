-- FIX RLS POLICY ISSUE
-- The RLS policy is blocking all recordings. Let's diagnose and fix it.

-- Step 1: Check what auth.uid() returns (will be NULL in SQL editor, but should work in app)
SELECT 
    'Auth UID Check' as check_type,
    auth.uid() as auth_uid,
    'NULL in SQL editor is normal - app uses JWT token' as note;

-- Step 2: Check all recordings and their user_id values
SELECT 
    'All Recordings' as check_type,
    id,
    name,
    user_id,
    user_id::text as user_id_text,
    deleted_at,
    created_at
FROM user_recordings
ORDER BY created_at DESC;

-- Step 3: Check the RLS policy definition
SELECT 
    'RLS Policy Definition' as check_type,
    policyname,
    cmd,
    roles,
    qual as using_clause,
    with_check
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'user_recordings'
  AND cmd = 'SELECT';

-- Step 4: Test if recordings would be visible with a specific user_id
-- Replace with your actual user_id from auth.users table
SELECT 
    'Test with Specific User ID' as check_type,
    COUNT(*) as count,
    'If this matches your recordings, RLS is the issue' as note
FROM user_recordings
WHERE user_id::text = '02c5f476-55fb-496d-9c6e-faa66470e2c9'
  AND deleted_at IS NULL;

-- Step 5: Check if user_id in recordings matches auth.users
SELECT 
    'User ID Verification' as check_type,
    ur.user_id,
    ur.user_id::text as user_id_text,
    CASE 
        WHEN au.id IS NOT NULL THEN '✅ User exists in auth.users'
        ELSE '❌ User NOT in auth.users'
    END as user_exists,
    COUNT(*) as recording_count
FROM user_recordings ur
LEFT JOIN auth.users au ON ur.user_id = au.id
GROUP BY ur.user_id, au.id
ORDER BY recording_count DESC;

-- Step 6: If the RLS policy is too restrictive, we can temporarily check what it should be
-- The policy should be: auth.uid() = user_id AND deleted_at IS NULL
-- But if auth.uid() is not matching, we need to verify the user_id format

-- Step 7: Show the exact policy SQL
SELECT 
    'Current SELECT Policy' as check_type,
    pg_get_expr(pol.polqual, pol.polrelid) as using_expression
FROM pg_policy pol
JOIN pg_class cls ON pol.polrelid = cls.oid
JOIN pg_namespace nsp ON cls.relnamespace = nsp.oid
WHERE nsp.nspname = 'public'
  AND cls.relname = 'user_recordings'
  AND pol.polcmd = 'r'; -- 'r' = SELECT

