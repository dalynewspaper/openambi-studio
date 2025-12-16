-- WIPE ALL RECORDINGS FROM DATABASE
-- This will completely delete all recordings for your user
-- WARNING: This is irreversible!

-- Step 1: Show what will be deleted
SELECT 
    'Records to Delete' as check_type,
    COUNT(*) as count,
    'These will be permanently deleted' as warning
FROM user_recordings
WHERE user_id::text = '02c5f476-55fb-496d-9c6e-faa66470e2c9';

-- Step 2: Show the recordings that will be deleted
SELECT 
    'Recordings to Delete' as check_type,
    id,
    name,
    file_path,
    created_at
FROM user_recordings
WHERE user_id::text = '02c5f476-55fb-496d-9c6e-faa66470e2c9'
ORDER BY created_at DESC;

-- Step 3: DELETE ALL RECORDINGS (HARD DELETE)
-- This permanently removes all recordings for your user
DELETE FROM user_recordings
WHERE user_id::text = '02c5f476-55fb-496d-9c6e-faa66470e2c9';

-- Step 4: Verify deletion
SELECT 
    'Verification' as check_type,
    COUNT(*) as remaining_count,
    CASE 
        WHEN COUNT(*) = 0 THEN '✅ All recordings deleted'
        ELSE '❌ Still have ' || COUNT(*) || ' recording(s)'
    END as status
FROM user_recordings
WHERE user_id::text = '02c5f476-55fb-496d-9c6e-faa66470e2c9';

-- Note: The audio files in storage are NOT deleted by this script
-- They will remain in Supabase Storage but won't be referenced in the database
-- If you want to delete the files too, you'll need to do that separately in Supabase Storage

