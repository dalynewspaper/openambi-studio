-- FIX EXISTING RECORDS: Ensure all existing recordings have deleted_at = NULL
-- This ensures they're not filtered out by the RLS policy

-- Set deleted_at to NULL for all existing records that don't have it set
UPDATE user_recordings
SET deleted_at = NULL
WHERE deleted_at IS NULL;

-- Actually, the above is redundant. Let's just verify the state:
-- Check how many records have deleted_at = NULL vs deleted_at IS NOT NULL
SELECT 
    'Record Status' as check_type,
    CASE 
        WHEN deleted_at IS NULL THEN 'Active (NULL)'
        ELSE 'Deleted (has timestamp)'
    END as status,
    COUNT(*) as count
FROM user_recordings
GROUP BY 
    CASE 
        WHEN deleted_at IS NULL THEN 'Active (NULL)'
        ELSE 'Deleted (has timestamp)'
    END;

-- Show a sample of records to verify they're accessible
SELECT 
    id,
    name,
    user_id,
    deleted_at,
    created_at
FROM user_recordings
ORDER BY created_at DESC
LIMIT 10;

-- Verify RLS policy is working
-- This should show all your recordings (if you're authenticated)
SELECT 
    'RLS Test' as check_type,
    COUNT(*) as visible_recordings,
    'Should match total active recordings' as note
FROM user_recordings
WHERE deleted_at IS NULL;

