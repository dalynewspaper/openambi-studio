-- Test direct SQL insert to verify RLS is actually disabled
-- This will help us determine if the issue is RLS or something else

-- Step 1: Verify RLS status
SELECT 
    'RLS Status' as test,
    rowsecurity as rls_enabled,
    CASE WHEN rowsecurity THEN 'ENABLED - This is the problem!' ELSE 'DISABLED - Good!' END as status
FROM pg_tables
WHERE tablename = 'user_recordings';

-- Step 2: Count existing policies
SELECT 
    'Policy Count' as test,
    COUNT(*) as policy_count,
    CASE WHEN COUNT(*) > 0 THEN 'POLICIES EXIST - Drop them!' ELSE 'No policies - Good!' END as status
FROM pg_policies
WHERE tablename = 'user_recordings';

-- Step 3: Try a direct SQL insert (this bypasses PostgREST)
-- Replace with a real UUID from your auth.users table
DO $$
DECLARE
    test_user_id uuid;
    test_recording_id uuid := gen_random_uuid();
BEGIN
    -- Get a real user ID from auth.users (use the first one found)
    SELECT id INTO test_user_id FROM auth.users LIMIT 1;
    
    IF test_user_id IS NULL THEN
        RAISE NOTICE 'No users found in auth.users - cannot test insert';
        RETURN;
    END IF;
    
    RAISE NOTICE 'Testing insert with user_id: %', test_user_id;
    RAISE NOTICE 'Testing insert with recording_id: %', test_recording_id;
    
    -- Try to insert
    INSERT INTO user_recordings (
        id,
        user_id,
        file_path,
        duration_seconds
    ) VALUES (
        test_recording_id,
        test_user_id,
        'test/path.m4a',
        10
    );
    
    RAISE NOTICE '✅ DIRECT SQL INSERT SUCCEEDED - RLS is disabled!';
    RAISE NOTICE 'The issue must be with PostgREST/API layer, not RLS';
    
    -- Clean up test record
    DELETE FROM user_recordings WHERE id = test_recording_id;
    RAISE NOTICE 'Cleaned up test record';
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ DIRECT SQL INSERT FAILED: %', SQLERRM;
    RAISE NOTICE 'This means RLS or another constraint is blocking the insert';
END $$;

-- Step 4: If direct SQL works but PostgREST doesn't, the issue is with PostgREST
-- PostgREST might be checking RLS even when it's disabled, or there's a caching issue

