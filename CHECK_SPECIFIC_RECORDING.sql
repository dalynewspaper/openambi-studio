-- CHECK SPECIFIC RECORDING THAT'S FAILING
-- The recording 4ca72d26-736b-4981-a994-b0a04f4fb121 is not being found

-- Check if recording exists with exact ID
SELECT 
    'Exact ID Match' as check_type,
    id,
    id::text as id_text,
    name,
    user_id,
    user_id::text as user_id_text,
    deleted_at,
    created_at
FROM user_recordings
WHERE id = '4ca72d26-736b-4981-a994-b0a04f4fb121'::uuid;

-- Check with text comparison (case insensitive)
SELECT 
    'Text ID Match' as check_type,
    id,
    id::text as id_text,
    name,
    user_id,
    deleted_at
FROM user_recordings
WHERE id::text = '4ca72d26-736b-4981-a994-b0a04f4fb121'
   OR LOWER(id::text) = LOWER('4ca72d26-736b-4981-a994-b0a04f4fb121');

-- Check with uppercase version
SELECT 
    'Uppercase ID Match' as check_type,
    id,
    id::text as id_text,
    name,
    user_id,
    deleted_at
FROM user_recordings
WHERE id::text = '4CA72D26-736B-4981-A994-B0A04F4FB121'
   OR UPPER(id::text) = UPPER('4CA72D26-736B-4981-A994-B0A04F4FB121');

-- Check all recordings for this user to see the ID format
SELECT 
    'All User Recordings' as check_type,
    id,
    id::text as id_text,
    name,
    deleted_at,
    created_at
FROM user_recordings
WHERE user_id::text = '02c5f476-55fb-496d-9c6e-faa66470e2c9'
ORDER BY created_at DESC;

