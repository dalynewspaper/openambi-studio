-- VERIFY AND FIX RLS POLICY
-- This script will verify the RLS policy is correct and fix it if needed

-- Step 1: Drop the existing SELECT policy
DROP POLICY IF EXISTS "Users can view own recordings" ON user_recordings;

-- Step 2: Recreate the SELECT policy with explicit NULL check
-- This ensures it works correctly with auth.uid()
CREATE POLICY "Users can view own recordings" ON user_recordings
    FOR SELECT 
    USING (
        auth.uid() IS NOT NULL AND
        auth.uid() = user_id AND
        deleted_at IS NULL
    );

-- Step 3: Verify the policy was created
SELECT 
    'Policy Created' as check_type,
    policyname,
    cmd,
    qual as using_clause
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'user_recordings'
  AND cmd = 'SELECT';

-- Step 4: Test the policy (will show 0 in SQL editor, but should work in app)
SELECT 
    'RLS Test' as check_type,
    COUNT(*) as visible_count,
    'Should match active recordings when authenticated in app' as note
FROM user_recordings
WHERE auth.uid() IS NOT NULL 
  AND auth.uid() = user_id 
  AND deleted_at IS NULL;

-- Step 5: Show what should be visible (bypassing RLS for verification)
SELECT 
    'Should Be Visible' as check_type,
    id,
    name,
    user_id,
    deleted_at,
    'These should appear in app' as note
FROM user_recordings
WHERE deleted_at IS NULL
ORDER BY created_at DESC;

