-- VERIFY IF NEW RECORDING APPEARS IN DATABASE
-- This script helps diagnose why new recordings aren't appearing in the app

-- Step 1: Check if the new recording exists (bypassing RLS)
SELECT 
    'New Recording Check' as check_type,
    id,
    name,
    user_id,
    deleted_at,
    created_at,
    updated_at,
    file_path,
    CASE 
        WHEN deleted_at IS NULL THEN '✅ Active (should appear)'
        ELSE '❌ Deleted (should NOT appear)'
    END as status
FROM user_recordings
WHERE id::text ILIKE '%9f807c90%'  -- Partial match for the new recording
   OR created_at > NOW() - INTERVAL '5 minutes'  -- Any recording from last 5 minutes
ORDER BY created_at DESC;

-- Step 2: Check all recordings for your user (bypassing RLS)
SELECT 
    'All User Recordings' as check_type,
    id,
    name,
    created_at,
    deleted_at,
    CASE 
        WHEN deleted_at IS NULL THEN 'Active'
        ELSE 'Deleted'
    END as status
FROM user_recordings
WHERE user_id::text = '02c5f476-55fb-496d-9c6e-faa66470e2c9'
ORDER BY created_at DESC;

-- Step 3: Check what RLS policy would see (simulating what the app sees)
-- Note: This will show 0 in SQL editor because auth.uid() is NULL there
-- But it shows the policy logic
SELECT 
    'RLS Filtered View' as check_type,
    COUNT(*) as count,
    'Should match app count when authenticated' as note
FROM user_recordings
WHERE auth.uid() IS NOT NULL 
  AND auth.uid() = user_id 
  AND deleted_at IS NULL;

-- Step 4: Check the most recent 10 recordings (bypassing RLS)
SELECT 
    'Most Recent Recordings' as check_type,
    id,
    name,
    created_at,
    deleted_at,
    EXTRACT(EPOCH FROM (NOW() - created_at)) as seconds_ago,
    CASE 
        WHEN deleted_at IS NULL THEN '✅ Active'
        ELSE '❌ Deleted'
    END as status
FROM user_recordings
WHERE user_id::text = '02c5f476-55fb-496d-9c6e-faa66470e2c9'
ORDER BY created_at DESC
LIMIT 10;

-- Step 5: Verify RLS is enabled and policies exist
SELECT 
    'RLS Status' as check_type,
    tablename,
    CASE WHEN rowsecurity THEN '✅ ENABLED' ELSE '❌ DISABLED' END as rls_status,
    (SELECT COUNT(*) FROM pg_policies WHERE schemaname = 'public' AND tablename = 'user_recordings') as policy_count
FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'user_recordings';

