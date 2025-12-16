-- Final RLS Fix V3 - Use a function to handle inserts
-- This bypasses the RLS policy check by using SECURITY DEFINER

-- Step 1: Create a function that handles the insert
-- This function runs with SECURITY DEFINER, so it bypasses RLS
CREATE OR REPLACE FUNCTION insert_user_recording(
    p_id uuid,
    p_file_path text,
    p_name text,
    p_category text,
    p_duration double precision,
    p_file_size bigint,
    p_recorded_at timestamp with time zone,
    p_description text DEFAULT NULL,
    p_location_name text DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_longitude double precision DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id uuid;
BEGIN
    -- Get the authenticated user's ID
    v_user_id := auth.uid();
    
    -- Insert the recording with the correct user_id
    INSERT INTO user_recordings (
        id,
        user_id,
        file_path,
        name,
        category,
        duration,
        file_size,
        recorded_at,
        description,
        location_name,
        latitude,
        longitude
    ) VALUES (
        p_id,
        v_user_id,  -- Always use auth.uid() from the function context
        p_file_path,
        p_name,
        p_category,
        p_duration,
        p_file_size,
        p_recorded_at,
        p_description,
        p_location_name,
        p_latitude,
        p_longitude
    );
    
    RETURN p_id;
END;
$$;

-- Step 2: Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION insert_user_recording TO authenticated;

-- Step 3: Update the RLS policy to allow the function to work
-- Since the function uses SECURITY DEFINER, it bypasses RLS, but we still need
-- to ensure users can call the function
-- Actually, with SECURITY DEFINER, the function bypasses RLS entirely

-- Step 4: Verify the function was created
SELECT 
    proname,
    prosecdef as is_security_definer,
    proargnames as parameter_names
FROM pg_proc
WHERE proname = 'insert_user_recording';

-- Now the app should call this function instead of direct INSERT
-- The function will handle setting user_id correctly and bypass RLS

