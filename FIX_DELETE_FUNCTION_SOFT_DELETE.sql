-- FIX DELETE FUNCTION TO USE SOFT DELETE
-- The current delete_user_recording function does a hard delete
-- This version uses soft delete (sets deleted_at) which is safer and allows recovery

CREATE OR REPLACE FUNCTION delete_user_recording(
    p_id uuid
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
        RAISE EXCEPTION 'User must be authenticated to delete recordings';
    END IF;
    
    -- Check if recording exists and get its user_id and deleted_at status
    SELECT user_id, deleted_at 
    INTO v_recording_user_id, v_deleted_at
    FROM user_recordings
    WHERE id = p_id;
    
    -- Check if recording was found
    IF v_recording_user_id IS NULL THEN
        RAISE EXCEPTION 'Recording not found with id: %. Current user: %. Please verify the recording exists and belongs to you.', 
            p_id::text, v_user_id::text;
    END IF;
    
    -- Check if recording is already deleted
    IF v_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION 'Recording has already been deleted. Recording id: %, deleted_at: %', 
            p_id::text, v_deleted_at::text;
    END IF;
    
    -- Check ownership
    IF v_recording_user_id != v_user_id THEN
        RAISE EXCEPTION 'You can only delete your own recordings. Recording belongs to user: %, but you are: %', 
            v_recording_user_id::text, v_user_id::text;
    END IF;
    
    -- Soft delete: set deleted_at timestamp instead of hard delete
    UPDATE user_recordings
    SET 
        deleted_at = NOW(),
        updated_at = NOW()
    WHERE id = p_id AND user_id = v_user_id AND deleted_at IS NULL;
    
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    
    IF v_rows_updated = 0 THEN
        RAISE EXCEPTION 'Failed to delete recording - no rows affected. Recording id: %, user_id: %, recording_user_id: %', 
            p_id::text, v_user_id::text, 
            COALESCE(v_recording_user_id::text, 'NULL');
    END IF;
    
    RETURN p_id;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION delete_user_recording(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_user_recording(uuid) TO anon;

-- Verify the function was created
SELECT 
    'Function Created' as check_type,
    proname as function_name,
    pg_get_function_arguments(oid) as arguments
FROM pg_proc
WHERE proname = 'delete_user_recording'
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

