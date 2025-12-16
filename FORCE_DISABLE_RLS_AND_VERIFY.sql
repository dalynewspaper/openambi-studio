-- Force disable RLS and verify it's actually disabled
-- This will help us determine if RLS is the real issue

-- Step 1: Check current RLS status
SELECT 
    'Current RLS Status' as check_type,
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename = 'user_recordings';

-- Step 2: List all policies (should be empty if RLS is disabled)
SELECT 
    'Current Policies' as check_type,
    policyname,
    cmd,
    roles,
    with_check
FROM pg_policies
WHERE tablename = 'user_recordings';

-- Step 3: FORCE disable RLS (drop all policies first, then disable)
DROP POLICY IF EXISTS "Users can insert own recordings" ON user_recordings;
DROP POLICY IF EXISTS "Allow all inserts for testing" ON user_recordings;
DROP POLICY IF EXISTS "delete_own_recordings" ON user_recordings;
DROP POLICY IF EXISTS "select_own_recordings" ON user_recordings;

-- Now disable RLS
ALTER TABLE user_recordings DISABLE ROW LEVEL SECURITY;

-- Step 4: Verify RLS is disabled
SELECT 
    'RLS Status After Disable' as check_type,
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename = 'user_recordings';

-- Step 5: Verify no policies exist
SELECT 
    'Policies After Cleanup' as check_type,
    COUNT(*) as policy_count
FROM pg_policies
WHERE tablename = 'user_recordings';

-- If RLS is disabled and there are no policies, inserts should work without any RLS checks

