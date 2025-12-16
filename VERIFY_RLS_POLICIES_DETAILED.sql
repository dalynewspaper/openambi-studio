-- VERIFY RLS POLICIES AND FUNCTIONS IN DETAIL
-- Run this to see the exact policy definitions

-- ============================================================================
-- STEP 1: Check RLS SELECT Policy (for viewing recordings)
-- ============================================================================
SELECT 
    'SELECT Policy' as check_type,
    policyname,
    qual as using_clause,
    with_check as with_check_clause,
    roles
FROM pg_policies
WHERE tablename = 'user_recordings'
  AND cmd = 'SELECT';

-- ============================================================================
-- STEP 2: Check RLS INSERT Policy (for creating recordings)
-- ============================================================================
SELECT 
    'INSERT Policy' as check_type,
    policyname,
    qual as using_clause,
    with_check as with_check_clause,
    roles
FROM pg_policies
WHERE tablename = 'user_recordings'
  AND cmd = 'INSERT';

-- ============================================================================
-- STEP 3: Check if insert_user_recording function exists
-- ============================================================================
SELECT 
    'INSERT Function' as check_type,
    proname as function_name,
    prosecdef as is_security_definer,
    pg_get_function_arguments(oid) as arguments,
    pg_get_functiondef(oid) as definition
FROM pg_proc
WHERE proname = 'insert_user_recording'
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

-- ============================================================================
-- STEP 4: Check trigger function definition
-- ============================================================================
SELECT 
    'Trigger Function' as check_type,
    proname as function_name,
    prosecdef as is_security_definer,
    pg_get_functiondef(oid) as definition
FROM pg_proc
WHERE proname = 'set_user_id_from_auth'
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

-- ============================================================================
-- STEP 5: Test query - Check if a specific recording is visible
-- ============================================================================
-- Replace with your actual recording ID and user ID from the logs
-- Example from logs: A54EC029-9FAB-4CB4-964E-BDD400D9BC8F
-- User ID: 02c5f476-55fb-496d-9c6e-faa66470e2c9

-- First, check if the recording exists at all (bypassing RLS)
SET ROLE postgres;
SELECT 
    'Recording Exists Check' as check_type,
    id,
    name,
    user_id,
    deleted_at,
    created_at
FROM user_recordings
WHERE id = 'A54EC029-9FAB-4CB4-964E-BDD400D9BC8F';  -- Replace with actual ID
RESET ROLE;

-- Then check if it's visible with RLS (as authenticated user)
-- Note: This will only work if you're authenticated in the SQL editor
SELECT 
    'RLS Visibility Check' as check_type,
    id,
    name,
    user_id,
    deleted_at
FROM user_recordings
WHERE id = 'A54EC029-9FAB-4CB4-964E-BDD400D9BC8F'  -- Replace with actual ID
  AND user_id = '02c5f476-55fb-496d-9c6e-faa66470e2c9'  -- Replace with actual user ID
  AND deleted_at IS NULL;
