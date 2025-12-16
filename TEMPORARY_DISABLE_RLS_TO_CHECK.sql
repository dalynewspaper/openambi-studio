-- TEMPORARILY DISABLE RLS TO CHECK IF RECORDINGS EXIST
-- Run this to see if recordings are actually in the database but being filtered by RLS

-- Step 1: Check recordings with RLS enabled
SELECT 
    'With RLS Enabled' as check_type,
    COUNT(*) as count
FROM user_recordings
WHERE deleted_at IS NULL;

-- Step 2: Temporarily disable RLS
ALTER TABLE user_recordings DISABLE ROW LEVEL SECURITY;

-- Step 3: Check recordings with RLS disabled
SELECT 
    'With RLS Disabled' as check_type,
    COUNT(*) as count,
    'All recordings visible' as note
FROM user_recordings
WHERE deleted_at IS NULL;

-- Step 4: Show all active recordings
SELECT 
    id,
    name,
    user_id,
    deleted_at,
    created_at
FROM user_recordings
WHERE deleted_at IS NULL
ORDER BY created_at DESC;

-- Step 5: Re-enable RLS
ALTER TABLE user_recordings ENABLE ROW LEVEL SECURITY;

-- Step 6: Verify RLS is re-enabled
SELECT 
    'RLS Status After Re-enable' as check_type,
    CASE WHEN rowsecurity THEN 'ENABLED' ELSE 'DISABLED' END as status
FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'user_recordings';

