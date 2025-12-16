-- CHECK USER_ID MISMATCH
-- This will help identify if there's a mismatch between auth.uid() and user_id in recordings

-- Step 1: Get your actual user ID from auth.users
-- This is what auth.uid() should return when you're authenticated
SELECT 
    'Your Auth User ID' as check_type,
    id,
    id::text as id_text,
    email,
    'This is what auth.uid() returns' as note
FROM auth.users
WHERE email = (SELECT email FROM auth.users LIMIT 1) -- Replace with your email if needed
ORDER BY created_at DESC
LIMIT 1;

-- Step 2: Check all recordings and their user_id
SELECT 
    'All Recordings with User IDs' as check_type,
    id as recording_id,
    name,
    user_id,
    user_id::text as user_id_text,
    deleted_at,
    created_at
FROM user_recordings
ORDER BY created_at DESC;

-- Step 3: Compare user_id in recordings vs auth.users
-- This will show if there's a mismatch
SELECT 
    'User ID Comparison' as check_type,
    ur.user_id as recording_user_id,
    ur.user_id::text as recording_user_id_text,
    au.id as auth_user_id,
    au.id::text as auth_user_id_text,
    CASE 
        WHEN ur.user_id = au.id THEN '✅ Match'
        ELSE '❌ Mismatch'
    END as match_status,
    COUNT(*) as recording_count
FROM user_recordings ur
LEFT JOIN auth.users au ON ur.user_id = au.id
GROUP BY ur.user_id, au.id
ORDER BY recording_count DESC;

-- Step 4: Check if recordings would match if we use the user_id from auth.users
-- Replace 'YOUR_USER_ID_HERE' with the actual user_id from Step 1
SELECT 
    'Recordings for Auth User' as check_type,
    COUNT(*) as count,
    'Should match what app sees' as note
FROM user_recordings
WHERE user_id = (SELECT id FROM auth.users ORDER BY created_at DESC LIMIT 1)
  AND deleted_at IS NULL;

-- Step 5: Show the exact format of user_id in recordings
SELECT 
    'User ID Format Analysis' as check_type,
    user_id,
    user_id::text as user_id_text,
    LOWER(user_id::text) as user_id_lower,
    UPPER(user_id::text) as user_id_upper,
    COUNT(*) as count
FROM user_recordings
GROUP BY user_id
ORDER BY count DESC;

