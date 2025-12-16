-- DIAGNOSE MISSING RECORDINGS
-- Run this to see what's actually in your database

-- Check all recordings (bypassing RLS for admin view)
-- Note: This will only work if you're running as a superuser or have the right permissions
SELECT 
    'All Recordings' as check_type,
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
ORDER BY created_at DESC
LIMIT 20;

-- Check recordings for a specific user (replace with your user_id)
-- Replace '02C5F476-55FB-496D-9C6E-FAA66470E2C9' with your actual user_id
SELECT 
    'User Recordings' as check_type,
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
WHERE user_id = '02C5F476-55FB-496D-9C6E-FAA66470E2C9'
ORDER BY created_at DESC;

-- Check the specific recording that's failing
SELECT 
    'Specific Recording' as check_type,
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
WHERE id = '5C07D3E6-B51E-4FFC-886D-36D1F56C2451';

-- Check RLS policies
SELECT 
    'RLS Policies' as check_type,
    policyname,
    cmd,
    roles,
    qual,
    with_check
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'user_recordings'
ORDER BY cmd, policyname;

-- Check if RLS is enabled
SELECT 
    'RLS Status' as check_type,
    tablename,
    CASE WHEN rowsecurity THEN 'ENABLED' ELSE 'DISABLED' END as status
FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'user_recordings';

