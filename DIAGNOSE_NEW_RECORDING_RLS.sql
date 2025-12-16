-- DIAGNOSE: Why new recordings appear in targeted fetch but not general fetch
-- This suggests an RLS SELECT policy issue

-- ============================================================================
-- STEP 1: Check if the recording exists in the database
-- ============================================================================
-- Replace with your actual recording ID and user ID
-- Example: A54EC029-9FAB-4CB4-964E-BDD400D9BC8F
SELECT 
    id,
    name,
    user_id,
    deleted_at,
    created_at,
    updated_at
FROM user_recordings
WHERE id = 'A54EC029-9FAB-4CB4-964E-BDD400D9BC8F'  -- Replace with actual ID
ORDER BY created_at DESC;

-- ============================================================================
-- STEP 2: Check RLS policies on user_recordings
-- ============================================================================
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'user_recordings'
ORDER BY policyname;

-- ============================================================================
-- STEP 3: Test the SELECT policy as the authenticated user
-- ============================================================================
-- This simulates what the general query does
-- Replace with your actual user ID
SELECT 
    id,
    name,
    user_id,
    deleted_at
FROM user_recordings
WHERE user_id = '02c5f476-55fb-496d-9c6e-faa66470e2c9'  -- Replace with actual user ID
  AND deleted_at IS NULL
ORDER BY created_at DESC;

-- ============================================================================
-- STEP 4: Check if RLS is enabled on the table
-- ============================================================================
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename = 'user_recordings';

-- ============================================================================
-- STEP 5: Check function definitions
-- ============================================================================
SELECT 
    proname as function_name,
    prosecdef as is_security_definer,
    proargnames as parameter_names,
    pg_get_function_arguments(oid) as arguments
FROM pg_proc
WHERE proname IN ('insert_user_recording', 'update_user_recording', 'delete_user_recording')
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
ORDER BY proname;

-- ============================================================================
-- STEP 6: Check for triggers that might be soft-deleting records
-- ============================================================================
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement,
    action_timing
FROM information_schema.triggers
WHERE event_object_table = 'user_recordings';

-- ============================================================================
-- EXPECTED RESULTS:
-- ============================================================================
-- 1. Recording should exist with deleted_at = NULL
-- 2. SELECT policy should allow: user_id = auth.uid() AND deleted_at IS NULL
-- 3. General query should return the recording
-- 4. If general query returns empty but targeted fetch works, RLS SELECT policy is the issue
