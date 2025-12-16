-- Create a database function to handle user recording inserts
-- This bypasses PostgREST's pre-validation of RLS policies
-- The function runs with SECURITY DEFINER, so it can set user_id from auth.uid()

-- IMPORTANT: This function must be created by a superuser (like postgres)
-- to properly bypass RLS. If you're not a superuser, you may need to
-- temporarily disable RLS or adjust the policy.

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
    -- SECURITY DEFINER should allow this to bypass RLS if function owner is superuser
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

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION insert_user_recording(uuid, text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION insert_user_recording(uuid, text, integer) TO anon;

-- Alternative: If SECURITY DEFINER doesn't bypass RLS, we can temporarily
-- disable RLS for this operation (less secure, but works)
-- This requires the function owner to have ALTER TABLE permission

-- Note: The function uses SECURITY DEFINER, so it runs with the privileges
-- of the function creator (typically a superuser), allowing it to bypass
-- RLS policies. However, it still checks auth.uid() to ensure only
-- authenticated users can insert, and always sets user_id = auth.uid().

