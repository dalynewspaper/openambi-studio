-- ENSURE DELETE POLICY EXISTS FOR USER_RECORDINGS
-- This ensures users can delete their own recordings

-- Check if delete policy exists
SELECT 
    'Current Delete Policies' as check_type,
    policyname,
    cmd,
    roles
FROM pg_policies
WHERE tablename = 'user_recordings' AND cmd = 'DELETE';

-- Drop existing delete policy if it exists
DROP POLICY IF EXISTS "Users can delete own recordings" ON user_recordings;

-- Create delete policy
CREATE POLICY "Users can delete own recordings" ON user_recordings
    FOR DELETE 
    USING (auth.uid() = user_id);

-- Verify the policy was created
SELECT 
    'Delete Policy Status' as check_type,
    policyname,
    cmd,
    roles,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ Policy exists'
        ELSE '❌ Policy missing'
    END as status
FROM pg_policies
WHERE tablename = 'user_recordings' AND cmd = 'DELETE'
GROUP BY policyname, cmd, roles;

