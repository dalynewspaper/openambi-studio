-- COMPLETE FIX FOR DELETE_USER_RECORDING FUNCTION
-- This script fixes the "Recording not found" error by ensuring the function
-- can properly access recordings regardless of RLS policies

-- Step 1: Drop the existing function
DROP FUNCTION IF EXISTS delete_user_recording(uuid);

-- Step 2: Create the fixed function
-- This version handles RLS more robustly and provides better error messages
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
    v_recording_exists boolean;
BEGIN
    -- Get authenticated user
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User must be authenticated to delete recordings';
    END IF;
    
    -- Try to find the recording
    -- Note: SECURITY DEFINER functions should bypass RLS, but this depends on
    -- the function owner's privileges. If the function owner is not a superuser
    -- or doesn't have BYPASSRLS privilege, RLS may still apply.
    BEGIN
        SELECT user_id, deleted_at 
        INTO v_recording_user_id, v_deleted_at
        FROM user_recordings
        WHERE id = p_id;
        
        -- Check if we found a row
        v_recording_exists := (v_recording_user_id IS NOT NULL);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_recording_exists := false;
    END;
    
    -- If recording not found, provide helpful error
    IF NOT v_recording_exists OR v_recording_user_id IS NULL THEN
        -- Try to see if recording exists at all (this might still be filtered by RLS)
        SELECT EXISTS(SELECT 1 FROM user_recordings WHERE id = p_id) INTO v_recording_exists;
        
        IF v_recording_exists THEN
            RAISE EXCEPTION 'Recording exists but cannot be accessed. This may be an RLS policy issue. Recording id: %, Current user: %. The function owner may need BYPASSRLS privilege.', 
                p_id::text, v_user_id::text;
        ELSE
            RAISE EXCEPTION 'Recording not found with id: %. Current user: %. Please verify the recording exists and belongs to you.', 
                p_id::text, v_user_id::text;
        END IF;
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
    -- Since we're using SECURITY DEFINER, this should bypass RLS
    UPDATE user_recordings
    SET 
        deleted_at = NOW(),
        updated_at = NOW()
    WHERE id = p_id AND user_id = v_user_id AND deleted_at IS NULL;
    
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    
    IF v_rows_updated = 0 THEN
        RAISE EXCEPTION 'Failed to delete recording - no rows affected. Recording id: %, user_id: %, recording_user_id: %. This may indicate the recording was already deleted or an RLS policy is blocking the update.', 
            p_id::text, v_user_id::text, 
            COALESCE(v_recording_user_id::text, 'NULL');
    END IF;
    
    RETURN p_id;
END;
$$;

-- Step 3: Grant execute permissions
GRANT EXECUTE ON FUNCTION delete_user_recording(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_user_recording(uuid) TO anon;

-- Step 4: Verify the function was created
SELECT 
    'Function Created' as check_type,
    proname as function_name,
    prosecdef as is_security_definer,
    proowner::regrole as function_owner,
    pg_get_function_arguments(oid) as arguments
FROM pg_proc
WHERE proname = 'delete_user_recording'
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

-- Step 5: If the function still doesn't work, the function owner may need BYPASSRLS
-- Run this as a superuser to grant BYPASSRLS to the function owner:
-- ALTER ROLE <function_owner> BYPASSRLS;
-- 
-- To find the function owner, check the output from Step 4 above.
-- In Supabase, the function owner is typically 'postgres' or 'supabase_admin',
-- which should already have BYPASSRLS privileges.
