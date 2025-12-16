-- FIX UPDATE AND DELETE PERSISTENCE ISSUES
-- The functions return success but changes don't persist
-- This is because RLS UPDATE policy's WITH CHECK clause blocks soft deletes
-- and UPDATE operations may be getting blocked by RLS even with SECURITY DEFINER

-- ============================================================================
-- STEP 1: Fix RLS UPDATE Policy to allow soft deletes
-- ============================================================================

DROP POLICY IF EXISTS "Users can update own recordings" ON user_recordings;

-- The WITH CHECK clause must allow deleted_at to be set (for soft deletes)
-- But still ensure user_id matches and user is authenticated
CREATE POLICY "Users can update own recordings" ON user_recordings
    FOR UPDATE 
    USING (
        -- Can only update if user is authenticated, owns the record, and it's not already deleted
        auth.uid() IS NOT NULL
        AND auth.uid() = user_id
        AND deleted_at IS NULL
    )
    WITH CHECK (
        -- After update, must still be authenticated and own the record
        -- BUT allow deleted_at to be set (for soft deletes)
        auth.uid() IS NOT NULL
        AND auth.uid() = user_id
        -- NOTE: We don't check deleted_at here because we need to allow soft deletes
        -- The SELECT policy will filter out deleted records anyway
    );

-- ============================================================================
-- STEP 2: Fix UPDATE function to ensure it actually updates
-- ============================================================================

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
    
    -- Verify recording exists and get ownership (bypassing RLS with SECURITY DEFINER)
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
    
    -- Perform the update - use CASE to only update non-NULL values
    -- This ensures we don't accidentally set fields to NULL when they shouldn't be
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
    WHERE id = p_id 
      AND user_id = v_user_id
      AND deleted_at IS NULL;
    
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    
    IF v_rows_updated = 0 THEN
        RAISE EXCEPTION 'Update failed - no rows affected. Recording id: %, user_id: %, recording_user_id: %', 
            p_id::text, v_user_id::text, v_recording_user_id::text;
    END IF;
    
    RETURN p_id;
END;
$$;

-- ============================================================================
-- STEP 3: Fix DELETE function to ensure it actually deletes (soft delete)
-- ============================================================================

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
    
    -- Verify recording exists and get ownership (bypassing RLS with SECURITY DEFINER)
    SELECT user_id, deleted_at 
    INTO v_recording_user_id, v_deleted_at
    FROM user_recordings
    WHERE id = p_id;
    
    IF v_recording_user_id IS NULL THEN
        RAISE EXCEPTION 'Recording not found: %', p_id::text;
    END IF;
    
    IF v_deleted_at IS NOT NULL THEN
        -- Already deleted - return success (idempotent)
        RETURN p_id;
    END IF;
    
    IF v_recording_user_id != v_user_id THEN
        RAISE EXCEPTION 'You can only delete your own recordings';
    END IF;
    
    -- Perform the soft delete
    -- SECURITY DEFINER should bypass RLS, but we still need to match user_id
    UPDATE user_recordings
    SET 
        deleted_at = NOW(),
        updated_at = NOW()
    WHERE id = p_id 
      AND user_id = v_user_id
      AND deleted_at IS NULL;
    
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    
    IF v_rows_updated = 0 THEN
        RAISE EXCEPTION 'Delete failed - no rows affected. Recording id: %, user_id: %, recording_user_id: %', 
            p_id::text, v_user_id::text, v_recording_user_id::text;
    END IF;
    
    RETURN p_id;
END;
$$;

-- ============================================================================
-- STEP 4: Grant permissions
-- ============================================================================

GRANT EXECUTE ON FUNCTION update_user_recording(uuid, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION update_user_recording(uuid, text, text, text, text) TO anon;

GRANT EXECUTE ON FUNCTION delete_user_recording(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_user_recording(uuid) TO anon;

-- ============================================================================
-- STEP 5: Verify the fixes
-- ============================================================================

-- Check UPDATE policy (should NOT require deleted_at IS NULL in WITH CHECK)
SELECT 
    'UPDATE Policy' as check_type,
    policyname,
    qual as using_clause,
    with_check as with_check_clause
FROM pg_policies
WHERE tablename = 'user_recordings'
  AND cmd = 'UPDATE';

-- Check DELETE policy
SELECT 
    'DELETE Policy' as check_type,
    policyname,
    qual as using_clause,
    with_check as with_check_clause
FROM pg_policies
WHERE tablename = 'user_recordings'
  AND cmd = 'DELETE';

-- Check functions
SELECT 
    'Functions' as check_type,
    proname as function_name,
    CASE WHEN prosecdef THEN 'SECURITY DEFINER' ELSE 'SECURITY INVOKER' END as security_type
FROM pg_proc
WHERE proname IN ('update_user_recording', 'delete_user_recording')
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

-- ============================================================================
-- EXPECTED RESULTS:
-- ============================================================================
-- After running this:
-- 1. UPDATE policy WITH CHECK should NOT require deleted_at IS NULL (allows soft deletes)
-- 2. UPDATE function should use CASE statements to only update non-NULL values
-- 3. DELETE function should properly set deleted_at = NOW()
-- 4. Updates should persist correctly
-- 5. Deletes should persist correctly (soft delete)
