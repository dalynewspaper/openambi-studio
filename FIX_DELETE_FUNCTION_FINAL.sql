-- FINAL FIX FOR DELETE_USER_RECORDING FUNCTION
-- This version explicitly handles RLS by using a more direct approach
-- Even with SECURITY DEFINER, RLS can still filter SELECT queries in some cases

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
    
    -- Directly attempt the UPDATE with ownership check
    -- This approach is more efficient and avoids RLS issues with SELECT
    -- We'll check the result to determine what happened
    UPDATE user_recordings
    SET 
        deleted_at = NOW(),
        updated_at = NOW()
    WHERE id = p_id 
      AND user_id = v_user_id 
      AND deleted_at IS NULL;
    
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    
    -- If no rows were updated, diagnose why
    IF v_rows_updated = 0 THEN
        -- Try to find the recording to provide a helpful error message
        -- This SELECT might still be filtered by RLS, but we'll try
        BEGIN
            SELECT user_id, deleted_at 
            INTO v_recording_user_id, v_deleted_at
            FROM user_recordings
            WHERE id = p_id;
            
            -- If we found it, provide specific error
            IF v_recording_user_id IS NOT NULL THEN
                IF v_deleted_at IS NOT NULL THEN
                    RAISE EXCEPTION 'Recording has already been deleted. Recording id: %, deleted_at: %', 
                        p_id::text, v_deleted_at::text;
                ELSIF v_recording_user_id != v_user_id THEN
                    RAISE EXCEPTION 'You can only delete your own recordings. Recording belongs to user: %, but you are: %', 
                        v_recording_user_id::text, v_user_id::text;
                ELSE
                    RAISE EXCEPTION 'Failed to delete recording - no rows affected despite ownership match. Recording id: %, user_id: %. This may indicate an RLS policy issue.', 
                        p_id::text, v_user_id::text;
                END IF;
            ELSE
                -- Recording not found (either doesn't exist or RLS is hiding it)
                RAISE EXCEPTION 'Recording not found with id: %. Current user: %. Please verify the recording exists and belongs to you.', 
                    p_id::text, v_user_id::text;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE EXCEPTION 'Recording not found with id: %. Current user: %. Please verify the recording exists and belongs to you.', 
                    p_id::text, v_user_id::text;
        END;
    END IF;
    
    RETURN p_id;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION delete_user_recording(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_user_recording(uuid) TO anon;

-- Verify the function was created
SELECT 
    'Function Updated' as check_type,
    proname as function_name,
    prosecdef as is_security_definer,
    proowner::regrole as function_owner,
    pg_get_function_arguments(oid) as arguments
FROM pg_proc
WHERE proname = 'delete_user_recording'
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');
