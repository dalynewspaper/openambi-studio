-- UPDATE INSERT FUNCTION TO INCLUDE NAME AND CATEGORY
-- The current function only saves id, user_id, file_path, and duration_seconds
-- But the table requires name (and category is expected by the app)

CREATE OR REPLACE FUNCTION insert_user_recording(
    p_id uuid,
    p_file_path text,
    p_duration_seconds integer DEFAULT NULL,
    p_name text DEFAULT NULL,
    p_category text DEFAULT NULL,
    p_description text DEFAULT NULL,
    p_icon text DEFAULT 'waveform',
    p_location_name text DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_longitude double precision DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id uuid;
    v_name text;
BEGIN
    -- Get the authenticated user's ID
    v_user_id := auth.uid();
    
    -- Check if user is authenticated
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User must be authenticated to insert recordings';
    END IF;
    
    -- Use provided name or generate a default
    v_name := COALESCE(p_name, 'Recording - ' || to_char(NOW(), 'HH24:MI'));
    
    -- Insert the recording with all fields
    INSERT INTO user_recordings (
        id,
        user_id,
        file_path,
        duration_seconds,
        name,
        category,
        description,
        icon,
        location_name,
        latitude,
        longitude
    ) VALUES (
        p_id,
        v_user_id,
        p_file_path,
        p_duration_seconds,
        v_name,
        p_category,
        p_description,
        COALESCE(p_icon, 'waveform'),
        p_location_name,
        p_latitude,
        p_longitude
    );
    
    RETURN p_id;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION insert_user_recording(uuid, text, integer, text, text, text, text, text, double precision, double precision) TO authenticated;
GRANT EXECUTE ON FUNCTION insert_user_recording(uuid, text, integer, text, text, text, text, text, double precision, double precision) TO anon;

