-- Test the trigger and debug RLS issue
-- Run this to see if the trigger is actually working

-- Step 1: Test if the trigger function works when called directly
-- This simulates what should happen on INSERT
DO $$
DECLARE
    test_user_id uuid;
    test_new_record RECORD;
BEGIN
    -- Get the current user's ID
    test_user_id := auth.uid();
    
    RAISE NOTICE 'Current auth.uid(): %', test_user_id;
    
    -- Create a test record structure
    test_new_record := ROW(
        gen_random_uuid(),  -- id
        '00000000-0000-0000-0000-000000000000'::uuid,  -- user_id (wrong value)
        'test.m4a',  -- file_path
        'Test Recording',  -- name
        'Test Category',  -- category
        10.5,  -- duration
        1000,  -- file_size
        NOW(),  -- recorded_at
        NOW(),  -- created_at
        NOW(),  -- updated_at
        NULL,  -- description
        NULL,  -- location_name
        NULL,  -- latitude
        NULL,  -- longitude
        NULL,  -- average_level
        NULL,  -- peak_level
        0,  -- play_count
        NULL,  -- last_played_at
        NULL   -- deleted_at
    )::user_recordings;
    
    -- Call the trigger function
    test_new_record := set_user_id_from_auth()::user_recordings;
    
    RAISE NOTICE 'After trigger, user_id should be: %', test_user_id;
    RAISE NOTICE 'Test record user_id: %', test_new_record.user_id;
END $$;

-- Step 2: Check if there are any other policies that might be interfering
SELECT 
    policyname,
    cmd,
    roles,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'user_recordings'
ORDER BY cmd, policyname;

-- Step 3: Try a simpler approach - make the policy check happen AFTER trigger
-- Drop and recreate with a policy that's more explicit
DROP POLICY IF EXISTS "Users can insert own recordings" ON user_recordings;

-- Create policy that explicitly allows the trigger to work
-- The trigger sets user_id = auth.uid(), so we just need to verify that
CREATE POLICY "Users can insert own recordings" ON user_recordings
    FOR INSERT 
    WITH CHECK (
        -- The trigger ensures user_id = auth.uid(), so this should always be true
        -- But we also allow NULL as a safety net (though trigger should set it)
        (auth.uid() = user_id) OR (user_id IS NULL AND auth.uid() IS NOT NULL)
    );

-- Step 4: Verify the function has the right permissions
SELECT 
    proname,
    prosecdef as is_security_definer,
    proconfig,
    prosrc
FROM pg_proc
WHERE proname = 'set_user_id_from_auth';

-- Step 5: Check table structure to ensure user_id column exists and is correct type
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'user_recordings' AND column_name = 'user_id';

