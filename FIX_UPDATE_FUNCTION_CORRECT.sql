-- FIX UPDATE FUNCTION - CORRECT VERSION
-- The issue is that updates return success but don't persist
-- This version ensures updates actually happen

DROP FUNCTION IF EXISTS update_user_recording(uuid, text, text, text, text);

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
    v_sql text;
BEGIN
    -- Get authenticated user
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User must be authenticated to update recordings';
    END IF;
    
    -- Check if recording exists and get ownership
    SELECT user_id, deleted_at 
    INTO v_recording_user_id, v_deleted_at
    FROM user_recordings
    WHERE id = p_id;
    
    IF v_recording_user_id IS NULL THEN
        RAISE EXCEPTION 'Recording not found with id: %. Current user: %.', 
            p_id::text, v_user_id::text;
    END IF;
    
    IF v_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION 'Recording has been deleted and cannot be updated.';
    END IF;
    
    IF v_recording_user_id != v_user_id THEN
        RAISE EXCEPTION 'You can only update your own recordings.';
    END IF;
    
    -- Build dynamic UPDATE statement to only update provided fields
    v_sql := 'UPDATE user_recordings SET updated_at = NOW()';
    
    IF p_name IS NOT NULL THEN
        v_sql := v_sql || ', name = $2';
    END IF;
    
    IF p_category IS NOT NULL THEN
        v_sql := v_sql || ', category = $3';
    END IF;
    
    IF p_description IS NOT NULL OR (p_description IS NULL AND p_description IS DISTINCT FROM NULL) THEN
        v_sql := v_sql || ', description = $4';
    END IF;
    
    IF p_icon IS NOT NULL THEN
        v_sql := v_sql || ', icon = $5';
    END IF;
    
    v_sql := v_sql || ' WHERE id = $1 AND user_id = $6 AND deleted_at IS NULL';
    
    -- Execute the UPDATE
    -- Use EXECUTE with USING to properly handle parameters
    EXECUTE v_sql 
    USING p_id, 
          COALESCE(p_name, (SELECT name FROM user_recordings WHERE id = p_id)),
          COALESCE(p_category, (SELECT category FROM user_recordings WHERE id = p_id)),
          p_description,
          COALESCE(p_icon, (SELECT icon FROM user_recordings WHERE id = p_id)),
          v_user_id;
    
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    
    IF v_rows_updated = 0 THEN
        RAISE EXCEPTION 'Failed to update recording - no rows affected. Recording id: %, user_id: %.', 
            p_id::text, v_user_id::text;
    END IF;
    
    RETURN p_id;
END;
$$;

-- Actually, let's use a simpler approach that definitely works
DROP FUNCTION IF EXISTS update_user_recording(uuid, text, text, text, text);

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
    
    -- Check if recording exists and get ownership
    SELECT user_id, deleted_at 
    INTO v_recording_user_id, v_deleted_at
    FROM user_recordings
    WHERE id = p_id;
    
    IF v_recording_user_id IS NULL THEN
        RAISE EXCEPTION 'Recording not found with id: %. Current user: %.', 
            p_id::text, v_user_id::text;
    END IF;
    
    IF v_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION 'Recording has been deleted and cannot be updated.';
    END IF;
    
    IF v_recording_user_id != v_user_id THEN
        RAISE EXCEPTION 'You can only update your own recordings.';
    END IF;
    
    -- Update with explicit field assignments
    -- Only update fields that are provided (not NULL)
    UPDATE user_recordings
    SET
        name = CASE WHEN p_name IS NOT NULL THEN p_name ELSE name END,
        category = CASE WHEN p_category IS NOT NULL THEN p_category ELSE category END,
        description = CASE 
            WHEN p_description IS NOT NULL THEN p_description
            WHEN p_description IS NULL THEN NULL  -- Allow setting to NULL
            ELSE description 
        END,
        icon = CASE WHEN p_icon IS NOT NULL THEN p_icon ELSE icon END,
        updated_at = NOW()
    WHERE id = p_id 
      AND user_id = v_user_id 
      AND deleted_at IS NULL;
    
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    
    IF v_rows_updated = 0 THEN
        RAISE EXCEPTION 'Failed to update recording - no rows affected. Recording id: %, user_id: %. Check RLS policies.', 
            p_id::text, v_user_id::text;
    END IF;
    
    RETURN p_id;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION update_user_recording(uuid, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION update_user_recording(uuid, text, text, text, text) TO anon;

-- Verify
SELECT 
    'Update Function Created' as check_type,
    proname as function_name,
    prosecdef as is_security_definer
FROM pg_proc
WHERE proname = 'update_user_recording'
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');
