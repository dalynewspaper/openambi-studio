-- FIX RLS SELECT POLICY - This is the root cause of recordings not appearing
-- The targeted fetch (by ID) works, but general fetch (by user_id) returns empty
-- This means the SELECT policy is blocking the general query

-- ============================================================================
-- STEP 0: Verify RLS is enabled
-- ============================================================================
SELECT 
    'RLS Status' as check_type,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename = 'user_recordings';

-- Enable RLS if not already enabled
ALTER TABLE user_recordings ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- STEP 1: Check current SELECT policy
-- ============================================================================
SELECT 
    'Current SELECT Policy' as check_type,
    policyname,
    qual as using_clause,
    with_check as with_check_clause
FROM pg_policies
WHERE tablename = 'user_recordings'
  AND cmd = 'SELECT';

-- ============================================================================
-- STEP 2: Drop ALL existing SELECT policies to avoid conflicts
-- ============================================================================

-- Drop all existing SELECT policies (there might be multiple with different names)
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'user_recordings' 
          AND cmd = 'SELECT'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON user_recordings', r.policyname);
        RAISE NOTICE 'Dropped policy: %', r.policyname;
    END LOOP;
END $$;

-- The policy must allow SELECT when:
-- 1. User is authenticated (auth.uid() IS NOT NULL)
-- 2. The user_id matches the authenticated user (auth.uid() = user_id)
-- 3. The record is not soft-deleted (deleted_at IS NULL)
-- 
-- IMPORTANT: Use direct UUID comparison (not text) for reliability
CREATE POLICY "Users can view own recordings" ON user_recordings
    FOR SELECT 
    USING (
        -- User must be authenticated
        auth.uid() IS NOT NULL
        AND
        -- User can only see their own recordings
        -- Direct UUID comparison (more reliable than text conversion)
        auth.uid() = user_id
        AND
        -- Exclude soft-deleted recordings
        deleted_at IS NULL
    );

-- ============================================================================
-- STEP 3: Verify the policy was created correctly
-- ============================================================================
SELECT 
    'SELECT Policy After Fix' as check_type,
    policyname,
    qual as using_clause,
    with_check as with_check_clause
FROM pg_policies
WHERE tablename = 'user_recordings'
  AND cmd = 'SELECT';

-- ============================================================================
-- STEP 4: Test query (replace with your actual user ID)
-- ============================================================================
-- This simulates what the app does - should return recordings
-- Replace '02c5f476-55fb-496d-9c6e-faa66470e2c9' with your actual user ID
SELECT 
    'Test Query' as check_type,
    id,
    name,
    user_id,
    deleted_at,
    created_at
FROM user_recordings
WHERE user_id = '02c5f476-55fb-496d-9c6e-faa66470e2c9'::uuid  -- Replace with your user ID
  AND deleted_at IS NULL
ORDER BY created_at DESC;

-- ============================================================================
-- STEP 5: Test as authenticated user (simulate app behavior)
-- ============================================================================
-- This requires setting the request role to 'authenticated' and providing a JWT
-- In Supabase SQL Editor, you can't easily test this, but the app will test it
-- 
-- To verify the policy works, check the app logs after running this fix:
-- - General fetch should return recordings (not empty array)
-- - "My Recordings" page should show all recordings

-- ============================================================================
-- EXPECTED RESULTS:
-- ============================================================================
-- After running this:
-- 1. SELECT policy should show: auth.uid() IS NOT NULL AND auth.uid() = user_id AND deleted_at IS NULL
-- 2. Test query (as postgres) should return all your non-deleted recordings
-- 3. General fetch in the app (as authenticated user) should now work correctly
-- 4. "My Recordings" page should display all recordings
