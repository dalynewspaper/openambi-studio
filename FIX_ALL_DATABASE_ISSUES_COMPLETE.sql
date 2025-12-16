-- COMPREHENSIVE FIX FOR ALL DATABASE ISSUES
-- This fixes: INSERT visibility, UPDATE persistence, DELETE persistence
-- Run this entire script in your Supabase SQL Editor

-- ============================================================================
-- STEP 1: FIX INSERT TRIGGER FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION set_user_id_from_auth()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public, pg_temp
LANGUAGE plpgsql
AS $$
BEGIN
    -- Get authenticated user ID
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'User must be authenticated to insert recordings';
    END IF;
    
    -- Force set user_id from auth.uid() - this overrides any value sent by client
    NEW.user_id := auth.uid();
    
    -- Set default values if not provided
    IF NEW.name IS NULL OR NEW.name = '' THEN
        NEW.name := 'Recording - ' || to_char(NOW(), 'HH24:MI');
    END IF;
    
    IF NEW.category IS NULL OR NEW.category = '' THEN
        NEW.category := 'My Recordings';
    END IF;
    
    IF NEW.icon IS NULL OR NEW.icon = '' THEN
        NEW.icon := 'waveform';
    END IF;
    
    -- Ensure deleted_at is NULL for new records
    NEW.deleted_at := NULL;
    
    -- Set timestamps
    IF NEW.created_at IS NULL THEN
        NEW.created_at := NOW();
    END IF;
    
    IF NEW.updated_at IS NULL THEN
        NEW.updated_at := NOW();
    END IF;
    
    RETURN NEW;
END;
$$;

-- Ensure trigger exists
DROP TRIGGER IF EXISTS trigger_set_user_id ON user_recordings;
CREATE TRIGGER trigger_set_user_id
    BEFORE INSERT ON user_recordings
    FOR EACH ROW
    EXECUTE FUNCTION set_user_id_from_auth();

-- ============================================================================
-- STEP 2: FIX RLS SELECT POLICY (for visibility of new recordings)
-- ============================================================================

DROP POLICY IF EXISTS "Users can view own recordings" ON user_recordings;

CREATE POLICY "Users can view own recordings" ON user_recordings
    FOR SELECT 
    USING (
        auth.uid() IS NOT NULL
        AND auth.uid() = user_id
        AND deleted_at IS NULL
    );

-- ============================================================================
-- STEP 3: FIX RLS INSERT POLICY
-- ============================================================================

DROP POLICY IF EXISTS "Users can insert own recordings" ON user_recordings;

CREATE POLICY "Users can insert own recordings" ON user_recordings
    FOR INSERT 
    WITH CHECK (
        auth.uid() IS NOT NULL
        AND (auth.uid() = user_id OR user_id IS NULL)
    );

-- ============================================================================
-- STEP 4: FIX UPDATE FUNCTION (from FIX_DATABASE_FUNCTIONS_COMPLETE.sql)
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
    
    -- Perform the update - SECURITY DEFINER should bypass RLS for this UPDATE
    UPDATE user_recordings
    SET
        name = COALESCE(p_name, name),
        category = COALESCE(p_category, category),
        description = p_description,  -- Allow NULL to be set explicitly
        icon = COALESCE(p_icon, icon),
        updated_at = NOW()
    WHERE id = p_id 
      AND user_id = v_user_id;
    
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    
    IF v_rows_updated = 0 THEN
        RAISE EXCEPTION 'Update failed - no rows affected. This may indicate an RLS policy issue.';
    END IF;
    
    RETURN p_id;
END;
$$;

-- ============================================================================
-- STEP 5: FIX DELETE FUNCTION (from FIX_DATABASE_FUNCTIONS_COMPLETE.sql)
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
        RAISE EXCEPTION 'Recording already deleted';
    END IF;
    
    IF v_recording_user_id != v_user_id THEN
        RAISE EXCEPTION 'You can only delete your own recordings';
    END IF;
    
    -- Perform the soft delete
    -- SECURITY DEFINER should bypass RLS for this UPDATE
    UPDATE user_recordings
    SET 
        deleted_at = NOW(),
        updated_at = NOW()
    WHERE id = p_id 
      AND user_id = v_user_id;
    
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    
    IF v_rows_updated = 0 THEN
        RAISE EXCEPTION 'Delete failed - no rows affected. This may indicate an RLS policy issue.';
    END IF;
    
    RETURN p_id;
END;
$$;

-- ============================================================================
-- STEP 6: GRANT PERMISSIONS
-- ============================================================================

GRANT EXECUTE ON FUNCTION update_user_recording(uuid, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION update_user_recording(uuid, text, text, text, text) TO anon;

GRANT EXECUTE ON FUNCTION delete_user_recording(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_user_recording(uuid) TO anon;

-- ============================================================================
-- STEP 7: VERIFY EVERYTHING
-- ============================================================================

-- Verify trigger
SELECT 
    'Trigger' as type,
    trigger_name as name,
    event_manipulation as event,
    action_timing as timing
FROM information_schema.triggers
WHERE event_object_table = 'user_recordings'
  AND trigger_name = 'trigger_set_user_id'

UNION ALL

-- Verify functions
SELECT 
    'Function' as type,
    proname as name,
    CASE WHEN prosecdef THEN 'SECURITY DEFINER' ELSE 'SECURITY INVOKER' END as event,
    '' as timing
FROM pg_proc
WHERE proname IN ('update_user_recording', 'delete_user_recording')
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')

UNION ALL

-- Verify policies
SELECT 
    'Policy' as type,
    policyname as name,
    cmd as event,
    '' as timing
FROM pg_policies
WHERE tablename = 'user_recordings'
ORDER BY type, name;

-- ============================================================================
-- IMPORTANT NOTES:
-- ============================================================================
-- 1. The trigger ensures user_id is always set correctly from auth.uid()
-- 2. The RLS SELECT policy will allow users to see their own non-deleted recordings
-- 3. The INSERT/UPDATE/DELETE functions use SECURITY DEFINER to bypass RLS
-- 4. After running this, test:
--    - Creating a new recording (should appear immediately)
--    - Updating a recording (should persist)
--    - Deleting a recording (should stay deleted)
