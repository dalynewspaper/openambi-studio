-- VERIFY AND FIX UPDATE/DELETE FUNCTIONS
-- This script checks if the functions are actually updating the database
-- and provides fixes if they're not working

-- Step 1: Check current function definitions
SELECT 
    'Current Functions' as check_type,
    proname as function_name,
    prosecdef as is_security_definer,
    proowner::regrole as function_owner,
    pg_get_functiondef(oid) as function_definition
FROM pg_proc
WHERE proname IN ('update_user_recording', 'delete_user_recording')
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

-- Step 2: Check if RLS is blocking updates
-- Test if we can see the recordings
SELECT 
    'RLS Test - Visible Recordings' as check_type,
    id,
    name,
    user_id,
    deleted_at,
    updated_at,
    'Should be visible if RLS allows' as note
FROM user_recordings
WHERE user_id::text = '02c5f476-55fb-496d-9c6e-faa66470e2c9'
ORDER BY created_at DESC
LIMIT 5;

-- Step 3: Recreate update function with explicit RLS bypass
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
    
    -- Check if recording exists (bypassing RLS with SECURITY DEFINER)
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
    
    -- Perform UPDATE - SECURITY DEFINER should bypass RLS
    UPDATE user_recordings
    SET
        name = COALESCE(p_name, name),
        category = COALESCE(p_category, category),
        description = p_description,  -- Allow NULL to be set
        icon = COALESCE(p_icon, icon),
        updated_at = NOW()
    WHERE id = p_id 
      AND user_id = v_user_id 
      AND deleted_at IS NULL;
    
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    
    IF v_rows_updated = 0 THEN
        RAISE EXCEPTION 'Failed to update recording - no rows affected. Recording id: %, user_id: %.', 
            p_id::text, v_user_id::text;
    END IF;
    
    RETURN p_id;
END;
$$;

-- Step 4: Recreate delete function with explicit RLS bypass
DROP FUNCTION IF EXISTS delete_user_recording(uuid);

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
    
    -- Check if recording exists (bypassing RLS with SECURITY DEFINER)
    SELECT user_id, deleted_at 
    INTO v_recording_user_id, v_deleted_at
    FROM user_recordings
    WHERE id = p_id;
    
    IF v_recording_user_id IS NULL THEN
        RAISE EXCEPTION 'Recording not found with id: %. Current user: %.', 
            p_id::text, v_user_id::text;
    END IF;
    
    IF v_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION 'Recording has already been deleted.';
    END IF;
    
    IF v_recording_user_id != v_user_id THEN
        RAISE EXCEPTION 'You can only delete your own recordings.';
    END IF;
    
    -- Perform soft delete - SECURITY DEFINER should bypass RLS
    UPDATE user_recordings
    SET 
        deleted_at = NOW(),
        updated_at = NOW()
    WHERE id = p_id 
      AND user_id = v_user_id 
      AND deleted_at IS NULL;
    
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    
    IF v_rows_updated = 0 THEN
        RAISE EXCEPTION 'Failed to delete recording - no rows affected. Recording id: %, user_id: %.', 
            p_id::text, v_user_id::text;
    END IF;
    
    RETURN p_id;
END;
$$;

-- Step 5: Grant permissions
GRANT EXECUTE ON FUNCTION update_user_recording(uuid, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION update_user_recording(uuid, text, text, text, text) TO anon;

GRANT EXECUTE ON FUNCTION delete_user_recording(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_user_recording(uuid) TO anon;

-- Step 6: Verify functions were created
SELECT 
    'Functions Created' as check_type,
    proname as function_name,
    prosecdef as is_security_definer,
    proowner::regrole as function_owner
FROM pg_proc
WHERE proname IN ('update_user_recording', 'delete_user_recording')
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');
