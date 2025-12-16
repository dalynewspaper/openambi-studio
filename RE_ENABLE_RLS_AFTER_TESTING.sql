-- Re-enable RLS after testing and apply proper security policy
-- Run this after confirming that inserts work with RLS disabled

-- Step 1: Re-enable RLS
ALTER TABLE user_recordings ENABLE ROW LEVEL SECURITY;

-- Step 2: Drop any test policies
DROP POLICY IF EXISTS "Allow all inserts for testing" ON user_recordings;
DROP POLICY IF EXISTS "Users can insert own recordings" ON user_recordings;

-- Step 3: Create proper INSERT policy
-- This allows authenticated users to insert when user_id matches auth.uid()
CREATE POLICY "Users can insert own recordings" ON user_recordings
    FOR INSERT 
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- Step 4: Verify the policy
SELECT 
    policyname,
    cmd,
    roles,
    with_check
FROM pg_policies
WHERE tablename = 'user_recordings' AND cmd = 'INSERT';

-- Step 5: Verify RLS is enabled
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename = 'user_recordings';

