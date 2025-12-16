-- QUICK FIX RLS POLICY
-- Run this to fix the RLS policy that's blocking all recordings

-- Drop and recreate the SELECT policy with explicit NULL check
DROP POLICY IF EXISTS "Users can view own recordings" ON user_recordings;

CREATE POLICY "Users can view own recordings" ON user_recordings
    FOR SELECT 
    USING (
        auth.uid() IS NOT NULL AND
        auth.uid() = user_id AND
        deleted_at IS NULL
    );

-- Verify it was created
SELECT 
    'RLS Policy Fixed' as check_type,
    policyname,
    cmd,
    qual as using_clause
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'user_recordings'
  AND cmd = 'SELECT';

-- Note: The test query will still show 0 in SQL editor because auth.uid() is NULL there
-- But it will work correctly when the app makes requests with a JWT token

