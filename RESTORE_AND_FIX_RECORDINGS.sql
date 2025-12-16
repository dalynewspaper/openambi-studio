-- RESTORE AND FIX RECORDINGS
-- This script will help diagnose and fix the missing recordings issue

-- ============================================================================
-- STEP 1: Check what's actually in the database (bypassing RLS)
-- ============================================================================

-- Count all recordings (including deleted)
SELECT 
    'Total Recordings' as check_type,
    COUNT(*) as count,
    'Including deleted' as note
FROM user_recordings;

-- Count active recordings (not deleted)
SELECT 
    'Active Recordings' as check_type,
    COUNT(*) as count,
    'deleted_at IS NULL' as filter
FROM user_recordings
WHERE deleted_at IS NULL;

-- Show all recordings with their status
SELECT 
    id,
    name,
    user_id,
    deleted_at,
    created_at,
    CASE 
        WHEN deleted_at IS NULL THEN 'Active'
        ELSE 'Deleted at ' || deleted_at::text
    END as status
FROM user_recordings
ORDER BY created_at DESC
LIMIT 50;

-- ============================================================================
-- STEP 2: Check if recordings exist for your user
-- ============================================================================

-- Replace with your actual user_id from the logs: 02C5F476-55FB-496D-9C6E-FAA66470E2C9
SELECT 
    'Your Recordings' as check_type,
    id,
    name,
    user_id,
    deleted_at,
    created_at,
    CASE 
        WHEN deleted_at IS NULL THEN 'Active'
        ELSE 'Deleted'
    END as status
FROM user_recordings
WHERE user_id::text = '02c5f476-55fb-496d-9c6e-faa66470e2c9'
ORDER BY created_at DESC;

-- ============================================================================
-- STEP 3: Check the specific recording that failed to update
-- ============================================================================

SELECT 
    'Failed Recording' as check_type,
    id,
    name,
    user_id,
    deleted_at,
    created_at,
    'This is the one that failed to update' as note
FROM user_recordings
WHERE id::text = '5c07d3e6-b51e-4ffc-886d-36d1f56c2451';

-- ============================================================================
-- STEP 4: If recordings exist but have deleted_at set, restore them
-- ============================================================================

-- Uncomment and run this if you find recordings with deleted_at set but want to restore them
-- UPDATE user_recordings
-- SET deleted_at = NULL
-- WHERE user_id::text = '02c5f476-55fb-496d-9c6e-faa66470e2c9'
--   AND deleted_at IS NOT NULL;

-- ============================================================================
-- STEP 5: Verify RLS policy is working correctly
-- ============================================================================

-- Test the SELECT policy by checking what an authenticated user would see
-- This simulates what the app sees
SELECT 
    'RLS Policy Test' as check_type,
    COUNT(*) as visible_recordings,
    'Should match active recordings for your user' as note
FROM user_recordings
WHERE auth.uid() = user_id 
  AND deleted_at IS NULL;

-- ============================================================================
-- STEP 6: Check if there's a mismatch in user_id format
-- ============================================================================

-- Check user_id format in recordings
SELECT 
    'User ID Format Check' as check_type,
    user_id,
    user_id::text as user_id_text,
    LOWER(user_id::text) as user_id_lower,
    COUNT(*) as count
FROM user_recordings
GROUP BY user_id
ORDER BY count DESC;

