-- TEMPORARY: Disable RLS on user_recordings for testing
-- This will allow ANYONE (even unauthenticated) to insert records
-- ONLY USE THIS FOR TESTING - Re-enable RLS after confirming inserts work!

-- Option 1: Completely disable RLS (easiest for testing)
ALTER TABLE user_recordings DISABLE ROW LEVEL SECURITY;

-- Option 2: If you want to keep RLS enabled but make it very permissive:
-- (Uncomment this and comment out Option 1 if you prefer)
-- DROP POLICY IF EXISTS "Users can insert own recordings" ON user_recordings;
-- CREATE POLICY "Allow all inserts for testing" ON user_recordings
--     FOR INSERT 
--     TO public  -- This allows even anonymous users!
--     WITH CHECK (true);

-- Verify RLS is disabled
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename = 'user_recordings';

-- After testing, re-enable RLS with:
-- ALTER TABLE user_recordings ENABLE ROW LEVEL SECURITY;
-- Then run SIMPLE_RLS_FIX.sql to restore proper security

