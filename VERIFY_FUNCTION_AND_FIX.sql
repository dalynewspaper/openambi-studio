-- Verify the function exists and check RLS policies
-- Run this to diagnose the issue

-- Step 1: Check if function exists
SELECT 
    proname as function_name,
    prosecdef as is_security_definer,
    proargnames as parameter_names,
    pg_get_functiondef(oid) as function_definition
FROM pg_proc
WHERE proname = 'insert_user_recording';

-- Step 2: Check current RLS policies on user_recordings
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

-- Step 3: If function doesn't exist or has issues, recreate it
-- Drop and recreate to ensure it's correct
DROP FUNCTION IF EXISTS insert_user_recording(uuid, text, integer);

CREATE OR REPLACE FUNCTION insert_user_recording(
    p_id uuid,
    p_file_path text,
    p_duration_seconds integer DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id uuid;
BEGIN
    -- Get the authenticated user's ID
    v_user_id := auth.uid();
    
    -- Check if user is authenticated
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User must be authenticated to insert recordings';
    END IF;
    
    -- Insert the recording with user_id set from auth.uid()
    -- SECURITY DEFINER should bypass RLS, but let's be explicit
    INSERT INTO user_recordings (
        id,
        user_id,
        file_path,
        duration_seconds
    ) VALUES (
        p_id,
        v_user_id,  -- Always use auth.uid(), ignore any provided value
        p_file_path,
        p_duration_seconds
    );
    
    RETURN p_id;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION insert_user_recording(uuid, text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION insert_user_recording(uuid, text, integer) TO anon;

-- Step 4: Verify the function is accessible
SELECT 
    'Function created successfully' as status,
    proname as function_name,
    prosecdef as is_security_definer
FROM pg_proc
WHERE proname = 'insert_user_recording';

