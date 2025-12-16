-- COMPREHENSIVE FIX FOR UPDATE/DELETE PERSISTENCE ISSUE
-- The functions return success but data doesn't persist
-- This ensures updates and deletes actually work

-- ============================================================================
-- STEP 1: DROP EXISTING FUNCTIONS
-- ============================================================================

DROP FUNCTION IF EXISTS update_user_recording(uuid, text, text, text, text);
DROP FUNCTION IF EXISTS delete_user_recording(uuid);

-- ============================================================================
-- STEP 2: CREATE UPDATE FUNCTION (SIMPLIFIED AND ROBUST)
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
    
    -- Verify recording exists and get ownership
    SELECT user_id, deleted_at 
    INTO v_recording_user_id, v_deleted_at
    FROM user_recordings
    WHERE id = p_id;
    
    IF v_recording_user_id IS NULL THEN
        RAISE EXCEPTION 'Recording not found: %', p_id::text;
    END IF;
    
    IF v_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION 'Recording has been deleted';
    END IF;
    
    IF v_recording_user_id != v_user_id THEN
        RAISE EXCEPTION 'You can only update your own recordings';
    END IF;
    
    -- Perform the update - use explicit assignments
    UPDATE user_recordings
    SET
        name = COALESCE(p_name, name),
        category = COALESCE(p_category, category),
        description = p_description,  -- This allows NULL to be set
        icon = COALESCE(p_icon, icon),
        updated_at = NOW()
    WHERE id = p_id 
      AND user_id = v_user_id;
    
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    
    IF v_rows_updated = 0 THEN
        RAISE EXCEPTION 'Update failed - no rows affected. ID: %, User: %', p_id::text, v_user_id::text;
    END IF;
    
    RETURN p_id;
END;
$$;

-- ============================================================================
-- STEP 3: CREATE DELETE FUNCTION (SIMPLIFIED AND ROBUST)
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
    
    -- Verify recording exists and get ownership
    SELECT user_id, deleted_at 
    INTO v_recording_user_id, v_deleted_at
    FROM user_recordings
    WHERE id = p_id;
    
    IF v_recording_user_id IS NULL THEN
        RAISE EXCEPTION 'Recording not found: %', p_id::text;
    END IF;
    
    IF v_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION 'Recording already deleted';
    END IF;
    
    IF v_recording_user_id != v_user_id THEN
        RAISE EXCEPTION 'You can only delete your own recordings';
    END IF;
    
    -- Perform the soft delete
    UPDATE user_recordings
    SET 
        deleted_at = NOW(),
        updated_at = NOW()
    WHERE id = p_id 
      AND user_id = v_user_id;
    
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    
    IF v_rows_updated = 0 THEN
        RAISE EXCEPTION 'Delete failed - no rows affected. ID: %, User: %', p_id::text, v_user_id::text;
    END IF;
    
    RETURN p_id;
END;
$$;

-- ============================================================================
-- STEP 4: GRANT PERMISSIONS
-- ============================================================================

GRANT EXECUTE ON FUNCTION update_user_recording(uuid, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION update_user_recording(uuid, text, text, text, text) TO anon;

GRANT EXECUTE ON FUNCTION delete_user_recording(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_user_recording(uuid) TO anon;

-- ============================================================================
-- STEP 5: VERIFY FUNCTIONS
-- ============================================================================

SELECT 
    'Functions Created' as status,
    proname as function_name,
    prosecdef as is_security_definer,
    proowner::regrole as owner
FROM pg_proc
WHERE proname IN ('update_user_recording', 'delete_user_recording')
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');
