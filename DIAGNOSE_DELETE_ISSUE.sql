-- DIAGNOSE DELETE RECORDING ISSUE
-- Run this to check why delete_user_recording is failing

-- Step 1: Check if the recording exists (bypassing RLS)
SELECT 
    'Recording Check' as check_type,
    id,
    name,
    user_id,
    deleted_at,
    created_at,
    'This shows all recordings regardless of RLS' as note
FROM user_recordings
WHERE id = '60F8EE23-6F6B-45D7-B1F3-2661FFB62DE5';

-- Step 2: Check current authenticated user
SELECT 
    'Current User' as check_type,
    auth.uid() as user_id,
    'This is the user making the request' as note;

-- Step 3: Check if recording is visible with RLS enabled
SELECT 
    'RLS Visibility Check' as check_type,
    id,
    name,
    user_id,
    deleted_at,
    'This shows what RLS allows you to see' as note
FROM user_recordings
WHERE id = '60F8EE23-6F6B-45D7-B1F3-2661FFB62DE5'
  AND auth.uid() = user_id
  AND deleted_at IS NULL;

-- Step 4: Check the delete function
SELECT 
    'Function Check' as check_type,
    proname as function_name,
    prosecdef as is_security_definer,
    proowner::regrole as function_owner,
    pg_get_functiondef(oid) as function_definition
FROM pg_proc
WHERE proname = 'delete_user_recording';

-- Step 5: Check RLS policies
SELECT 
    'RLS Policy Check' as check_type,
    policyname,
    cmd,
    qual as using_clause,
    with_check
FROM pg_policies
WHERE tablename = 'user_recordings';

-- Step 6: Check if RLS is enabled
SELECT 
    'RLS Status' as check_type,
    CASE WHEN rowsecurity THEN 'ENABLED' ELSE 'DISABLED' END as status
FROM pg_tables
WHERE tablename = 'user_recordings';
