-- VERIFY THAT DELETED RECORDINGS ARE PROPERLY FILTERED
-- This script helps diagnose why deleted recordings might be reappearing

-- Step 1: Check all recordings for your user (including deleted ones)
SELECT 
    'All User Recordings (Including Deleted)' as check_type,
    id,
    name,
    created_at,
    deleted_at,
    CASE 
        WHEN deleted_at IS NULL THEN '✅ Active (should appear)'
        ELSE '❌ Deleted (should NOT appear)'
    END as status
FROM user_recordings
WHERE user_id::text = '02c5f476-55fb-496d-9c6e-faa66470e2c9'
ORDER BY created_at DESC;

-- Step 2: Check only active (non-deleted) recordings
SELECT 
    'Active Recordings Only' as check_type,
    id,
    name,
    created_at,
    deleted_at,
    '✅ Active' as status
FROM user_recordings
WHERE user_id::text = '02c5f476-55fb-496d-9c6e-faa66470e2c9'
  AND deleted_at IS NULL
ORDER BY created_at DESC;

-- Step 3: Check deleted recordings count
SELECT 
    'Deleted Recordings Count' as check_type,
    COUNT(*) as deleted_count,
    'These should NOT appear in the app' as note
FROM user_recordings
WHERE user_id::text = '02c5f476-55fb-496d-9c6e-faa66470e2c9'
  AND deleted_at IS NOT NULL;

-- Step 4: Verify RLS policy is working
-- Note: This will show 0 in SQL editor because auth.uid() is NULL there
-- But it shows the policy logic
SELECT 
    'RLS Filtered View (Active Only)' as check_type,
    COUNT(*) as count,
    'Should match app count when authenticated' as note
FROM user_recordings
WHERE auth.uid() IS NOT NULL 
  AND auth.uid() = user_id 
  AND deleted_at IS NULL;

-- Step 5: Check if there are any recordings with NULL deleted_at that should be deleted
SELECT 
    'Potentially Orphaned Active Recordings' as check_type,
    id,
    name,
    created_at,
    'Check if these should be deleted' as note
FROM user_recordings
WHERE user_id::text = '02c5f476-55fb-496d-9c6e-faa66470e2c9'
  AND deleted_at IS NULL
  AND created_at < NOW() - INTERVAL '1 day'  -- Older than 1 day
ORDER BY created_at DESC;

