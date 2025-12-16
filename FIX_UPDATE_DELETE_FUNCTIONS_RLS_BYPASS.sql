-- FIX UPDATE AND DELETE FUNCTIONS TO PROPERLY BYPASS RLS
-- The issue is that UPDATE statements in SECURITY DEFINER functions may still be filtered by RLS
-- These versions ensure the updates actually persist to the database

-- ============================================================================
-- FIX UPDATE FUNCTION
-- ============================================================================

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
    
    -- Check if recording exists and get ownership info
    SELECT user_id, deleted_at 
    INTO v_recording_user_id, v_deleted_at
    FROM user_recordings
    WHERE id = p_id;
    
    -- Check if recording was found
    IF v_recording_user_id IS NULL THEN
        RAISE EXCEPTION 'Recording not found with id: %. Current user: %. Please verify the recording exists and belongs to you.', 
            p_id::text, v_user_id::text;
    END IF;
    
    -- Check if recording is deleted
    IF v_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION 'Recording has been deleted and cannot be updated. Recording id: %, user_id: %', 
            p_id::text, v_user_id::text;
    END IF;
    
    -- Check ownership
    IF v_recording_user_id != v_user_id THEN
        RAISE EXCEPTION 'You can only update your own recordings. Recording belongs to user: %, but you are: %', 
            v_recording_user_id::text, v_user_id::text;
    END IF;
    
    -- Perform the UPDATE
    -- SECURITY DEFINER should bypass RLS, but we'll be explicit
    UPDATE user_recordings
    SET
        name = CASE WHEN p_name IS NOT NULL THEN p_name ELSE name END,
        category = CASE WHEN p_category IS NOT NULL THEN p_category ELSE category END,
        description = CASE 
            WHEN p_description IS NOT NULL THEN p_description 
            WHEN p_description IS NULL THEN NULL
            ELSE description 
        END,
        icon = CASE WHEN p_icon IS NOT NULL THEN p_icon ELSE icon END,
        updated_at = NOW()
    WHERE id = p_id 
      AND user_id = v_user_id 
      AND deleted_at IS NULL;
    
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    
    IF v_rows_updated = 0 THEN
        RAISE EXCEPTION 'Failed to update recording - no rows affected. Recording id: %, user_id: %, recording_user_id: %. This may indicate an RLS policy issue.', 
            p_id::text, v_user_id::text, 
            COALESCE(v_recording_user_id::text, 'NULL');
    END IF;
    
    RETURN p_id;
END;
$$;

-- ============================================================================
-- FIX DELETE FUNCTION
-- ============================================================================

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
    
    -- Check if recording exists and get ownership info
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
    
    -- Perform the soft delete
    -- SECURITY DEFINER should bypass RLS, but we'll be explicit
    UPDATE user_recordings
    SET 
        deleted_at = NOW(),
        updated_at = NOW()
    WHERE id = p_id 
      AND user_id = v_user_id 
      AND deleted_at IS NULL;
    
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    
    IF v_rows_updated = 0 THEN
        RAISE EXCEPTION 'Failed to delete recording - no rows affected. Recording id: %, user_id: %, recording_user_id: %. This may indicate an RLS policy issue.', 
            p_id::text, v_user_id::text, 
            COALESCE(v_recording_user_id::text, 'NULL');
    END IF;
    
    RETURN p_id;
END;
$$;

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

GRANT EXECUTE ON FUNCTION update_user_recording(uuid, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION update_user_recording(uuid, text, text, text, text) TO anon;

GRANT EXECUTE ON FUNCTION delete_user_recording(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_user_recording(uuid) TO anon;

-- ============================================================================
-- VERIFY FUNCTIONS
-- ============================================================================

SELECT 
    'Function Status' as check_type,
    proname as function_name,
    prosecdef as is_security_definer,
    proowner::regrole as function_owner,
    pg_get_function_arguments(oid) as arguments
FROM pg_proc
WHERE proname IN ('update_user_recording', 'delete_user_recording')
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');
