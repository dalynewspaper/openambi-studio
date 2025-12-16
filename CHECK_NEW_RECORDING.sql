-- CHECK IF NEW RECORDING EXISTS IN DATABASE
-- Run this to verify if the newly saved recording is actually in the database
-- Replace the UUID below with the recording ID from the logs

-- Check for the specific recording that was just saved
-- Recording ID: 9F807C90-E5D2-4FAA-A392-F37EACBE0712
SELECT 
    'Specific Recording Check' as check_type,
    id,
    name,
    user_id,
    deleted_at,
    created_at,
    updated_at,
    CASE 
        WHEN deleted_at IS NULL THEN 'Active'
        ELSE 'Deleted'
    END as status
FROM user_recordings
WHERE id = '9f807c90-e5d2-4faa-a392-f37eacbe0712';

-- Check all recordings for your user (bypassing RLS for verification)
-- Replace with your actual user_id
SELECT 
    'All User Recordings' as check_type,
    id,
    name,
    user_id,
    deleted_at,
    created_at,
    updated_at,
    CASE 
        WHEN deleted_at IS NULL THEN 'Active'
        ELSE 'Deleted'
    END as status
FROM user_recordings
WHERE user_id::text = '02c5f476-55fb-496d-9c6e-faa66470e2c9'
ORDER BY created_at DESC;

-- Check the most recent recordings (should include the new one)
SELECT 
    'Most Recent Recordings' as check_type,
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
ORDER BY created_at DESC
LIMIT 10;

-- Check RLS policy to see if it would filter out the new recording
SELECT 
    'RLS Policy Check' as check_type,
    policyname,
    cmd,
    qual as using_clause
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'user_recordings'
  AND cmd = 'SELECT';

