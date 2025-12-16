-- CHECK SPECIFIC RECORDINGS STATUS
-- This will show the exact status of your 3 recordings

-- Show all 3 recordings with full details
SELECT 
    id,
    name,
    user_id,
    deleted_at,
    created_at,
    updated_at,
    file_path,
    duration_seconds,
    icon,
    CASE 
        WHEN deleted_at IS NULL THEN '✅ Active (should be visible)'
        ELSE '❌ Deleted (hidden by RLS)'
    END as status,
    CASE 
        WHEN deleted_at IS NULL AND user_id::text = '02c5f476-55fb-496d-9c6e-faa66470e2c9' THEN 'Should appear in app'
        WHEN deleted_at IS NOT NULL THEN 'Hidden - deleted_at is set'
        ELSE 'Hidden - wrong user_id'
    END as visibility
FROM user_recordings
WHERE user_id::text = '02c5f476-55fb-496d-9c6e-faa66470e2c9'
ORDER BY created_at DESC;

-- Check if any have deleted_at set (this would hide them)
SELECT 
    'Deleted Status Summary' as check_type,
    COUNT(*) FILTER (WHERE deleted_at IS NULL) as active_count,
    COUNT(*) FILTER (WHERE deleted_at IS NOT NULL) as deleted_count,
    COUNT(*) as total_count
FROM user_recordings
WHERE user_id::text = '02c5f476-55fb-496d-9c6e-faa66470e2c9';

-- If any recordings have deleted_at set incorrectly, run this to restore them:
-- UPDATE user_recordings
-- SET deleted_at = NULL
-- WHERE user_id::text = '02c5f476-55fb-496d-9c6e-faa66470e2c9'
--   AND deleted_at IS NOT NULL;

-- Check the specific recording that failed to update
SELECT 
    'Failed Update Recording' as check_type,
    id,
    name,
    user_id,
    deleted_at,
    created_at,
    CASE 
        WHEN id::text = '5c07d3e6-b51e-4ffc-886d-36d1f56c2451' THEN 'This is the one that failed'
        ELSE 'Not the failed one'
    END as note
FROM user_recordings
WHERE id::text = '5c07d3e6-b51e-4ffc-886d-36d1f56c2451'
   OR id::text = '5C07D3E6-B51E-4FFC-886D-36D1F56C2451';

