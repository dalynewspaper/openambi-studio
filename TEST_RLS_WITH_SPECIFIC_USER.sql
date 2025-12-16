-- TEST RLS WITH SPECIFIC USER
-- This simulates what the app should see when authenticated

-- First, get your user ID from auth.users
-- Replace this with your actual email or user ID
DO $$
DECLARE
    v_user_id uuid;
    v_count integer;
BEGIN
    -- Get the user ID (replace with your email or use the first user)
    SELECT id INTO v_user_id 
    FROM auth.users 
    ORDER BY created_at DESC 
    LIMIT 1;
    
    RAISE NOTICE 'Testing with user_id: %', v_user_id;
    
    -- Count what should be visible (simulating RLS)
    SELECT COUNT(*) INTO v_count
    FROM user_recordings
    WHERE user_id = v_user_id
      AND deleted_at IS NULL;
    
    RAISE NOTICE 'Recordings that should be visible: %', v_count;
    
    -- Show the recordings
    RAISE NOTICE 'Recording details:';
    FOR rec IN 
        SELECT id, name, user_id, deleted_at, created_at
        FROM user_recordings
        WHERE user_id = v_user_id
          AND deleted_at IS NULL
        ORDER BY created_at DESC
    LOOP
        RAISE NOTICE '  - ID: %, Name: %, Created: %', rec.id, rec.name, rec.created_at;
    END LOOP;
END $$;

-- Also show a simple query result
SELECT 
    'Test Result' as check_type,
    COUNT(*) as visible_recordings,
    'These should appear in app' as note
FROM user_recordings ur
WHERE ur.user_id = (SELECT id FROM auth.users ORDER BY created_at DESC LIMIT 1)
  AND ur.deleted_at IS NULL;

