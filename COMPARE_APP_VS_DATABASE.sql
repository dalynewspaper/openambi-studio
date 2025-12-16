-- COMPARE APP VS DATABASE
-- This will help us understand why the app shows 6 recordings but database shows 3

-- Step 1: Count ALL recordings for your user (including deleted)
SELECT 
    'Total Recordings (All)' as check_type,
    COUNT(*) as count
FROM user_recordings
WHERE user_id::text = '02c5f476-55fb-496d-9c6e-faa66470e2c9';

-- Step 2: Count ACTIVE recordings (not deleted)
SELECT 
    'Active Recordings (Not Deleted)' as check_type,
    COUNT(*) as count
FROM user_recordings
WHERE user_id::text = '02c5f476-55fb-496d-9c6e-faa66470e2c9'
  AND deleted_at IS NULL;

-- Step 3: Show ALL recordings with full details
SELECT 
    id,
    name,
    category,
    user_id,
    deleted_at,
    created_at,
    duration_seconds,
    icon,
    CASE 
        WHEN deleted_at IS NULL THEN '✅ Active'
        ELSE '❌ Deleted'
    END as status
FROM user_recordings
WHERE user_id::text = '02c5f476-55fb-496d-9c6e-faa66470e2c9'
ORDER BY created_at DESC;

-- Step 4: Check if there are recordings with different user_id format
-- (in case there's a case sensitivity issue)
SELECT 
    'User ID Variations' as check_type,
    user_id,
    user_id::text as user_id_text,
    COUNT(*) as count
FROM user_recordings
WHERE LOWER(user_id::text) = '02c5f476-55fb-496d-9c6e-faa66470e2c9'
GROUP BY user_id
ORDER BY count DESC;

-- Step 5: Check what RLS would return (simulating authenticated query)
-- Note: This will only work if you're authenticated in the SQL editor
-- If auth.uid() returns NULL, the count will be 0
SELECT 
    'RLS Filtered Count' as check_type,
    COUNT(*) as count,
    'What the app should see via RLS' as note
FROM user_recordings
WHERE auth.uid() = user_id 
  AND deleted_at IS NULL;

