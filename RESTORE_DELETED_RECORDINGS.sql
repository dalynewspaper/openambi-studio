-- RESTORE DELETED RECORDINGS
-- If your recordings have deleted_at set, this will restore them

-- First, check which recordings are marked as deleted
SELECT 
    'Deleted Recordings Check' as check_type,
    id,
    name,
    user_id,
    deleted_at,
    created_at,
    'These will be restored' as action
FROM user_recordings
WHERE user_id::text = '02c5f476-55fb-496d-9c6e-faa66470e2c9'
  AND deleted_at IS NOT NULL;

-- Restore all deleted recordings for your user
-- This sets deleted_at to NULL, making them visible again
UPDATE user_recordings
SET deleted_at = NULL,
    updated_at = NOW()
WHERE user_id::text = '02c5f476-55fb-496d-9c6e-faa66470e2c9'
  AND deleted_at IS NOT NULL;

-- Verify the restoration
SELECT 
    'After Restoration' as check_type,
    COUNT(*) FILTER (WHERE deleted_at IS NULL) as active_count,
    COUNT(*) FILTER (WHERE deleted_at IS NOT NULL) as deleted_count,
    COUNT(*) as total_count
FROM user_recordings
WHERE user_id::text = '02c5f476-55fb-496d-9c6e-faa66470e2c9';

-- Show all active recordings
SELECT 
    'Active Recordings' as check_type,
    id,
    name,
    user_id,
    deleted_at,
    created_at,
    'Should now be visible in app' as status
FROM user_recordings
WHERE user_id::text = '02c5f476-55fb-496d-9c6e-faa66470e2c9'
  AND deleted_at IS NULL
ORDER BY created_at DESC;

