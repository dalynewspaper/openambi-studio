-- FIX UPDATE_USER_RECORDING FUNCTION
-- This fixes the function to properly handle NULL values and provide better error messages

CREATE OR REPLACE FUNCTION update_user_recording(
    p_id uuid,
    p_name text DEFAULT NULL,
    p_category text DEFAULT NULL,
    p_description text DEFAULT NULL,
    p_icon text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id uuid;
    v_recording_user_id uuid;
    v_deleted_at timestamp with time zone;
    v_rows_updated integer;
BEGIN
    -- Get authenticated user
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User must be authenticated to update recordings';
    END IF;
    
    -- First check if recording exists at all
    -- Use SECURITY DEFINER context to bypass RLS for this check
    SELECT user_id, deleted_at INTO STRICT v_recording_user_id, v_deleted_at
    FROM user_recordings
    WHERE id = p_id;
    
    -- If we get here and v_recording_user_id is still NULL, the recording truly doesn't exist
    IF v_recording_user_id IS NULL THEN
        RAISE EXCEPTION 'Recording not found with id: %. Check if the recording exists in the database.', p_id;
    END IF;
    
    -- Check if recording is deleted
    IF v_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION 'Recording has been deleted and cannot be updated';
    END IF;
    
    -- Check ownership
    IF v_recording_user_id != v_user_id THEN
        RAISE EXCEPTION 'You can only update your own recordings. Recording belongs to user: %, but you are: %', v_recording_user_id, v_user_id;
    END IF;
    
    -- Update only provided fields
    -- Use CASE to allow NULL values to be set (COALESCE would keep existing value if NULL)
    UPDATE user_recordings
    SET
        name = CASE WHEN p_name IS NOT NULL THEN p_name ELSE name END,
        category = CASE WHEN p_category IS NOT NULL THEN p_category ELSE category END,
        description = CASE 
            WHEN p_description IS NOT NULL THEN p_description 
            WHEN p_description IS NULL AND p_description IS DISTINCT FROM NULL THEN NULL
            ELSE description 
        END,
        icon = CASE WHEN p_icon IS NOT NULL THEN p_icon ELSE icon END,
        updated_at = NOW()
    WHERE id = p_id AND user_id = v_user_id AND deleted_at IS NULL;
    
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    
    IF v_rows_updated = 0 THEN
        RAISE EXCEPTION 'Failed to update recording - no rows affected. Recording id: %, user_id: %', p_id, v_user_id;
    END IF;
    
    RETURN p_id;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION update_user_recording(uuid, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION update_user_recording(uuid, text, text, text, text) TO anon;

