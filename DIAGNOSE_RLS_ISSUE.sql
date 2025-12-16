-- Diagnose RLS Issue
-- Run this to see what's actually happening

-- Step 1: Test if auth.uid() works in the trigger function context
DO $$
DECLARE
    test_uid uuid;
BEGIN
    test_uid := auth.uid();
    RAISE NOTICE 'auth.uid() in DO block: %', test_uid;
    
    IF test_uid IS NULL THEN
        RAISE NOTICE '⚠️ WARNING: auth.uid() is NULL - user is not authenticated in this context';
    ELSE
        RAISE NOTICE '✅ auth.uid() is available: %', test_uid;
    END IF;
END $$;

-- Step 2: Test the trigger function directly
DO $$
DECLARE
    test_record RECORD;
    test_uid uuid;
BEGIN
    test_uid := auth.uid();
    RAISE NOTICE 'Testing trigger function with auth.uid(): %', test_uid;
    
    -- Create a test NEW record
    test_record := ROW(
        gen_random_uuid(),
        '00000000-0000-0000-0000-000000000000'::uuid,  -- wrong user_id
        'test.m4a',
        'Test',
        'Test',
        10.0,
        1000,
        NOW(),
        NOW(),
        NOW(),
        NULL, NULL, NULL, NULL, NULL, NULL, 0, NULL, NULL
    )::user_recordings;
    
    -- Try to call the trigger function (this won't work directly, but let's see)
    RAISE NOTICE 'Cannot directly test trigger, but checking if function exists...';
END $$;

-- Step 3: Check the actual trigger function code
SELECT 
    proname,
    prosecdef,
    prosrc
FROM pg_proc
WHERE proname = 'set_user_id_from_auth';

-- Step 4: Check if there are any other policies that might be interfering
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'user_recordings';

-- Step 5: Try a different approach - make the policy check the trigger's result
-- Drop and recreate with a policy that's guaranteed to work with the trigger
DROP POLICY IF EXISTS "Users can insert own recordings" ON user_recordings;

-- Create policy that checks AFTER trigger has run
-- The trigger sets user_id = auth.uid(), so we just need to verify user is authenticated
CREATE POLICY "Users can insert own recordings" ON user_recordings
    FOR INSERT 
    WITH CHECK (
        -- Since trigger ALWAYS sets user_id = auth.uid(), we just need to check auth exists
        -- But also verify the trigger worked by checking user_id matches
        (auth.uid() IS NOT NULL) AND (user_id = auth.uid())
    );

-- Step 6: Verify the new policy
SELECT 
    policyname,
    cmd,
    with_check
FROM pg_policies
WHERE tablename = 'user_recordings' AND cmd = 'INSERT';

