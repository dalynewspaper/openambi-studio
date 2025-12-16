-- COMPLETE RLS DISABLE - This will allow ANYONE to insert
-- Run this to completely disable RLS for testing

-- Step 1: Drop ALL policies (just to be sure)
DROP POLICY IF EXISTS "Users can insert own recordings" ON user_recordings;
DROP POLICY IF EXISTS "Allow all inserts for testing" ON user_recordings;
DROP POLICY IF EXISTS "delete_own_recordings" ON user_recordings;
DROP POLICY IF EXISTS "select_own_recordings" ON user_recordings;

-- Step 2: DISABLE RLS on the table itself
ALTER TABLE user_recordings DISABLE ROW LEVEL SECURITY;

-- Step 3: Verify RLS is disabled
SELECT 
    'VERIFICATION' as status,
    tablename,
    rowsecurity as rls_enabled,
    CASE 
        WHEN rowsecurity THEN '❌ STILL ENABLED - Run ALTER TABLE again!'
        ELSE '✅ DISABLED - RLS is off!'
    END as result
FROM pg_tables
WHERE tablename = 'user_recordings';

-- Step 4: Verify no policies exist
SELECT 
    'POLICY CHECK' as status,
    COUNT(*) as remaining_policies,
    CASE 
        WHEN COUNT(*) > 0 THEN '❌ POLICIES STILL EXIST!'
        ELSE '✅ NO POLICIES - Good!'
    END as result
FROM pg_policies
WHERE tablename = 'user_recordings';

-- If both show RLS disabled and 0 policies, inserts should work without any RLS checks
-- If you still get RLS errors after this, the issue is with PostgREST caching or something else

