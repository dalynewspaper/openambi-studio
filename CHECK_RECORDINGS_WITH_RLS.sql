-- CHECK RECORDINGS WITH RLS ACTIVE
-- This will show what an authenticated user can see

-- First, let's see all recordings regardless of RLS
SELECT 
    'All Recordings (Bypass RLS)' as check_type,
    id,
    name,
    user_id,
    deleted_at,
    created_at
FROM user_recordings
ORDER BY created_at DESC;

-- Now check what auth.uid() returns (this will be NULL if not authenticated in SQL editor)
-- But we can check the recordings for the specific user
SELECT 
    'Recordings for User' as check_type,
    id,
    name,
    user_id,
    deleted_at,
    created_at,
    CASE 
        WHEN deleted_at IS NULL THEN 'Should be visible'
        ELSE 'Deleted - hidden'
    END as visibility
FROM user_recordings
WHERE user_id::text = '02c5f476-55fb-496d-9c6e-faa66470e2c9'
ORDER BY created_at DESC;

-- Check if any have deleted_at set
SELECT 
    'Deleted Status Check' as check_type,
    COUNT(*) FILTER (WHERE deleted_at IS NULL) as active_count,
    COUNT(*) FILTER (WHERE deleted_at IS NOT NULL) as deleted_count,
    COUNT(*) as total_count
FROM user_recordings
WHERE user_id::text = '02c5f476-55fb-496d-9c6e-faa66470e2c9';

-- If any recordings have deleted_at set but shouldn't, uncomment this to fix:
-- UPDATE user_recordings
-- SET deleted_at = NULL
-- WHERE user_id::text = '02c5f476-55fb-496d-9c6e-faa66470e2c9'
--   AND deleted_at IS NOT NULL;

