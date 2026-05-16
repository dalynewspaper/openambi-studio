-- ============================================================================
-- COMPREHENSIVE DATABASE AUDIT AND FIX
-- This script audits all database functions and policies, then fixes them
-- Run this in Supabase SQL Editor to ensure bulletproof policies
-- ============================================================================

-- ============================================================================
-- PART 1: AUDIT - LIST ALL CURRENT FUNCTIONS AND POLICIES
-- ============================================================================

-- 1.1: List all functions related to user_recordings
SELECT 
    '=== FUNCTIONS AUDIT ===' as section,
    '' as detail;

SELECT 
    'Function' as type,
    proname as name,
    pg_get_function_arguments(oid) as arguments,
    CASE WHEN prosecdef THEN 'SECURITY DEFINER' ELSE 'SECURITY INVOKER' END as security_type,
    proowner::regrole as owner,
    prosrc as source_code
FROM pg_proc
WHERE pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
  AND (
    proname LIKE '%recording%' 
    OR proname LIKE '%user_recordings%'
    OR proname IN ('set_user_id_from_auth', 'update_updated_at_column')
  )
ORDER BY proname;

-- 1.2: List all RLS policies on user_recordings table
SELECT 
    '=== RLS POLICIES AUDIT ===' as section,
    '' as detail;

SELECT 
    'RLS Policy' as type,
    policyname as name,
    cmd as operation,
    roles::text as roles,
    qual as using_clause,
    with_check as with_check_clause
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'user_recordings'
ORDER BY cmd, policyname;

-- 1.3: Check RLS status
SELECT 
    '=== RLS STATUS ===' as section,
    '' as detail;

SELECT 
    'RLS Status' as type,
    tablename as name,
    CASE WHEN rowsecurity THEN 'ENABLED' ELSE 'DISABLED' END as status
FROM pg_tables
WHERE schemaname = 'public' 
  AND tablename = 'user_recordings';

-- 1.4: List all triggers
SELECT 
    '=== TRIGGERS AUDIT ===' as section,
    '' as detail;

SELECT 
    'Trigger' as type,
    trigger_name as name,
    event_manipulation as event,
    action_timing as timing,
    action_statement as statement
FROM information_schema.triggers
WHERE event_object_schema = 'public'
  AND event_object_table = 'user_recordings'
ORDER BY trigger_name;

-- 1.5: List storage policies for user-recordings bucket
SELECT 
    '=== STORAGE POLICIES AUDIT ===' as section,
    '' as detail;

SELECT 
    'Storage Policy' as type,
    policyname as name,
    cmd as operation,
    roles::text as roles,
    qual as using_clause,
    with_check as with_check_clause
FROM pg_policies
WHERE schemaname = 'storage' 
  AND tablename = 'objects'
  AND policyname LIKE '%recording%'
ORDER BY cmd, policyname;

-- ============================================================================
-- PART 2: FIX - DROP AND RECREATE ALL FUNCTIONS AND POLICIES
-- ============================================================================

-- 2.1: Drop all existing policies (clean slate)
DROP POLICY IF EXISTS "Users can view own recordings" ON user_recordings;
DROP POLICY IF EXISTS "Users can insert own recordings" ON user_recordings;
DROP POLICY IF EXISTS "Users can update own recordings" ON user_recordings;
DROP POLICY IF EXISTS "Users can delete own recordings" ON user_recordings;
DROP POLICY IF EXISTS "Authenticated users can view own recordings" ON user_recordings;
DROP POLICY IF EXISTS "Authenticated users can insert own recordings" ON user_recordings;
DROP POLICY IF EXISTS "Authenticated users can update own recordings" ON user_recordings;
DROP POLICY IF EXISTS "Authenticated users can delete own recordings" ON user_recordings;

-- 2.2: Drop existing triggers (they depend on functions)
DROP TRIGGER IF EXISTS trigger_set_user_id ON user_recordings;
DROP TRIGGER IF EXISTS update_user_recordings_updated_at ON user_recordings;

-- 2.3: Drop all existing functions
DROP FUNCTION IF EXISTS insert_user_recording CASCADE;
DROP FUNCTION IF EXISTS update_user_recording(uuid, text, text, text, text);
DROP FUNCTION IF EXISTS delete_user_recording(uuid);
DROP FUNCTION IF EXISTS set_user_id_from_auth() CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;

-- 2.4: Ensure RLS is enabled
ALTER TABLE user_recordings ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- PART 3: CREATE BULLETPROOF RLS POLICIES
-- ============================================================================

-- 3.1: SELECT Policy - Users can only see their own non-deleted recordings
-- CRITICAL: Must exclude deleted_at IS NOT NULL
CREATE POLICY "Users can view own recordings" ON user_recordings
    FOR SELECT 
    TO authenticated
    USING (
        -- User must be authenticated
        auth.uid() IS NOT NULL
        AND
        -- User can only see their own recordings
        auth.uid() = user_id
        AND
        -- CRITICAL: Exclude soft-deleted recordings
        deleted_at IS NULL
    );

-- 3.2: INSERT Policy - Users can only insert recordings with their own user_id
CREATE POLICY "Users can insert own recordings" ON user_recordings
    FOR INSERT 
    TO authenticated
    WITH CHECK (
        -- User must be authenticated
        auth.uid() IS NOT NULL
        AND
        -- User can only insert with their own user_id
        -- (trigger will enforce this, but policy provides extra security)
        auth.uid() = user_id
        AND
        -- Cannot insert with deleted_at already set
        deleted_at IS NULL
    );

-- 3.3: UPDATE Policy - Users can only update their own non-deleted recordings
-- CRITICAL: Must prevent updating deleted records
CREATE POLICY "Users can update own recordings" ON user_recordings
    FOR UPDATE 
    TO authenticated
    USING (
        -- User must be authenticated
        auth.uid() IS NOT NULL
        AND
        -- User can only update their own recordings
        auth.uid() = user_id
        AND
        -- CRITICAL: Cannot update deleted records
        deleted_at IS NULL
    )
    WITH CHECK (
        -- Same checks for the updated row
        auth.uid() IS NOT NULL
        AND
        auth.uid() = user_id
        AND
        -- CRITICAL: Cannot set deleted_at via UPDATE (must use delete function)
        deleted_at IS NULL
    );

-- 3.4: DELETE Policy - Users can only delete their own recordings
-- Note: We use soft delete via function, but this policy allows hard delete if needed
CREATE POLICY "Users can delete own recordings" ON user_recordings
    FOR DELETE 
    TO authenticated
    USING (
        -- User must be authenticated
        auth.uid() IS NOT NULL
        AND
        -- User can only delete their own recordings
        auth.uid() = user_id
    );

-- ============================================================================
-- PART 4: CREATE BULLETPROOF TRIGGER FUNCTIONS
-- ============================================================================

-- 4.1: Function to automatically set user_id from auth.uid() on INSERT
CREATE OR REPLACE FUNCTION set_user_id_from_auth()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    -- CRITICAL: Always set user_id from auth.uid() to prevent RLS violations
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'User must be authenticated to insert recordings';
    END IF;
    
    NEW.user_id := auth.uid();
    
    -- Ensure deleted_at is NULL on insert
    NEW.deleted_at := NULL;
    
    -- Set defaults if not provided
    IF NEW.name IS NULL OR NEW.name = '' THEN
        NEW.name := 'Recording - ' || to_char(NOW(), 'HH24:MI');
    END IF;
    
    IF NEW.category IS NULL OR NEW.category = '' THEN
        NEW.category := 'My Recordings';
    END IF;
    
    IF NEW.icon IS NULL OR NEW.icon = '' THEN
        NEW.icon := 'waveform';
    END IF;
    
    IF NEW.created_at IS NULL THEN
        NEW.created_at := NOW();
    END IF;
    
    IF NEW.updated_at IS NULL THEN
        NEW.updated_at := NOW();
    END IF;
    
    RETURN NEW;
END;
$$;

-- 4.2: Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

-- 4.3: Recreate triggers
CREATE TRIGGER trigger_set_user_id
    BEFORE INSERT ON user_recordings
    FOR EACH ROW
    EXECUTE FUNCTION set_user_id_from_auth();

CREATE TRIGGER update_user_recordings_updated_at
    BEFORE UPDATE ON user_recordings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- PART 5: CREATE BULLETPROOF DATABASE FUNCTIONS
-- ============================================================================

-- 5.1: INSERT Function - Insert user recording
-- Parameter order: id, file_path, duration_seconds, name, category, description, icon, location_name, latitude, longitude
CREATE OR REPLACE FUNCTION insert_user_recording(
    p_id uuid,
    p_file_path text,
    p_duration_seconds integer DEFAULT NULL,
    p_name text DEFAULT NULL,
    p_category text DEFAULT NULL,
    p_description text DEFAULT NULL,
    p_icon text DEFAULT NULL,
    p_location_name text DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_longitude double precision DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id uuid;
    v_name text;
BEGIN
    -- Get authenticated user
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User must be authenticated to insert recordings';
    END IF;
    
    -- Generate default name if not provided
    v_name := COALESCE(p_name, 'Recording - ' || to_char(NOW(), 'HH24:MI'));
    
    -- Insert the recording
    -- Trigger will set user_id, but we set it here too for safety
    INSERT INTO user_recordings (
        id,
        user_id,
        file_path,
        duration_seconds,
        name,
        category,
        description,
        icon,
        location_name,
        latitude,
        longitude,
        deleted_at  -- Explicitly set to NULL
    ) VALUES (
        p_id,
        v_user_id,
        p_file_path,
        p_duration_seconds,
        v_name,
        COALESCE(p_category, 'My Recordings'),
        p_description,
        COALESCE(p_icon, 'waveform'),
        p_location_name,
        p_latitude,
        p_longitude,
        NULL  -- Explicitly NULL for deleted_at
    );
    
    RETURN p_id;
END;
$$;

-- 5.2: UPDATE Function - Update user recording
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
    
    -- Check if recording was found
    IF v_recording_user_id IS NULL THEN
        RAISE EXCEPTION 'Recording not found with id: %. Current user: %.', 
            p_id::text, v_user_id::text;
    END IF;
    
    -- CRITICAL: Check if recording is deleted
    IF v_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION 'Recording has been deleted and cannot be updated. Recording id: %, deleted_at: %', 
            p_id::text, v_deleted_at::text;
    END IF;
    
    -- Check ownership
    IF v_recording_user_id != v_user_id THEN
        RAISE EXCEPTION 'You can only update your own recordings. Recording belongs to user: %, but you are: %', 
            v_recording_user_id::text, v_user_id::text;
    END IF;
    
    -- Perform the update
    -- SECURITY DEFINER should bypass RLS, but we still check user_id
    UPDATE user_recordings
    SET
        name = COALESCE(p_name, name),
        category = COALESCE(p_category, category),
        description = p_description,  -- Allow NULL to be set explicitly
        icon = COALESCE(p_icon, icon),
        updated_at = NOW()
    WHERE id = p_id 
      AND user_id = v_user_id 
      AND deleted_at IS NULL;  -- CRITICAL: Only update non-deleted records
    
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    
    IF v_rows_updated = 0 THEN
        RAISE EXCEPTION 'Failed to update recording - no rows affected. Recording id: %, user_id: %, recording_user_id: %, deleted_at: %', 
            p_id::text, v_user_id::text, 
            COALESCE(v_recording_user_id::text, 'NULL'),
            COALESCE(v_deleted_at::text, 'NULL');
    END IF;
    
    RETURN p_id;
END;
$$;

-- 5.3: DELETE Function - Soft delete user recording
-- CRITICAL: This must set deleted_at, not hard delete
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
    
    -- Check if recording was found
    IF v_recording_user_id IS NULL THEN
        -- Idempotent: if recording doesn't exist, consider it already deleted
        RAISE NOTICE 'Recording not found (may already be deleted): %', p_id::text;
        RETURN p_id;
    END IF;
    
    -- Check if recording is already deleted
    IF v_deleted_at IS NOT NULL THEN
        -- Idempotent: if already deleted, return success
        RAISE NOTICE 'Recording already deleted: %, deleted_at: %', p_id::text, v_deleted_at::text;
        RETURN p_id;
    END IF;
    
    -- Check ownership
    IF v_recording_user_id != v_user_id THEN
        RAISE EXCEPTION 'You can only delete your own recordings. Recording belongs to user: %, but you are: %', 
            v_recording_user_id::text, v_user_id::text;
    END IF;
    
    -- CRITICAL: Perform SOFT DELETE by setting deleted_at
    -- SECURITY DEFINER should bypass RLS for this UPDATE
    UPDATE user_recordings
    SET 
        deleted_at = NOW(),
        updated_at = NOW()
    WHERE id = p_id 
      AND user_id = v_user_id 
      AND deleted_at IS NULL;  -- Only delete if not already deleted
    
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    
    IF v_rows_updated = 0 THEN
        RAISE EXCEPTION 'Failed to delete recording - no rows affected. Recording id: %, user_id: %, recording_user_id: %, deleted_at: %', 
            p_id::text, v_user_id::text, 
            COALESCE(v_recording_user_id::text, 'NULL'),
            COALESCE(v_deleted_at::text, 'NULL');
    END IF;
    
    RETURN p_id;
END;
$$;

-- ============================================================================
-- PART 6: GRANT PERMISSIONS
-- ============================================================================

-- Grant execute permissions to authenticated and anon roles
GRANT EXECUTE ON FUNCTION insert_user_recording(uuid, text, integer, text, text, text, text, text, double precision, double precision) TO authenticated;
GRANT EXECUTE ON FUNCTION insert_user_recording(uuid, text, integer, text, text, text, text, text, double precision, double precision) TO anon;

GRANT EXECUTE ON FUNCTION update_user_recording(uuid, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION update_user_recording(uuid, text, text, text, text) TO anon;

GRANT EXECUTE ON FUNCTION delete_user_recording(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_user_recording(uuid) TO anon;

-- ============================================================================
-- PART 7: FUTURE-PROOFING - PREPARE FOR PUBLIC USERNAMES
-- ============================================================================

-- 7.1: Check if public_username column exists, add if not
DO $$
BEGIN
    -- Check if we need to add public_username column for future sharing/selling features
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'user_recordings' 
          AND column_name = 'public_username'
    ) THEN
        -- We'll add this later when implementing sharing features
        -- For now, just note it in comments
        RAISE NOTICE 'Future: public_username column will be added for sharing/selling features';
    ELSE
        RAISE NOTICE 'public_username column already exists';
    END IF;
END $$;

-- 7.2: Check if is_public column exists for future public sharing
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'user_recordings' 
          AND column_name = 'is_public'
    ) THEN
        RAISE NOTICE 'Future: is_public column will be added for public sharing features';
    ELSE
        RAISE NOTICE 'is_public column already exists';
    END IF;
END $$;

-- Note: When implementing public usernames and sharing:
-- 1. Add public_username column to user_recordings (or create separate user_profiles table)
-- 2. Add is_public boolean column to user_recordings
-- 3. Update SELECT policy to allow public access when is_public = true
-- 4. Add unique constraint on public_username
-- 5. Create index on public_username for fast lookups
-- 6. Update RLS policies to allow SELECT for public recordings

-- ============================================================================
-- PART 8: VERIFICATION
-- ============================================================================

-- 8.1: Verify RLS status
SELECT 
    '=== VERIFICATION: RLS STATUS ===' as check_type,
    tablename,
    CASE WHEN rowsecurity THEN 'ENABLED ✓' ELSE 'DISABLED ✗' END as status
FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'user_recordings';

-- 8.2: Verify policies
SELECT 
    '=== VERIFICATION: POLICIES ===' as check_type,
    policyname,
    cmd as operation,
    roles::text as roles
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'user_recordings'
ORDER BY cmd, policyname;

-- 8.3: Verify functions
SELECT 
    '=== VERIFICATION: FUNCTIONS ===' as check_type,
    proname as function_name,
    CASE WHEN prosecdef THEN 'SECURITY DEFINER ✓' ELSE 'SECURITY INVOKER' END as security_type
FROM pg_proc
WHERE pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
  AND proname IN ('insert_user_recording', 'update_user_recording', 'delete_user_recording', 'set_user_id_from_auth', 'update_updated_at_column')
ORDER BY proname;

-- 8.4: Verify triggers
SELECT 
    '=== VERIFICATION: TRIGGERS ===' as check_type,
    trigger_name,
    event_manipulation as event,
    action_timing as timing
FROM information_schema.triggers
WHERE event_object_schema = 'public'
  AND event_object_table = 'user_recordings'
ORDER BY trigger_name;

-- ============================================================================
-- SUMMARY
-- ============================================================================

SELECT 
    '=== SUMMARY ===' as section,
    'All functions and policies have been recreated with bulletproof security' as status;

-- Key improvements:
-- 1. SELECT policy explicitly excludes deleted_at IS NOT NULL
-- 2. UPDATE policy prevents updating deleted records
-- 3. DELETE function performs SOFT DELETE (sets deleted_at)
-- 4. All functions use SECURITY DEFINER to bypass RLS reliably
-- 5. All functions verify ownership before operations
-- 6. Delete function is idempotent (safe to call multiple times)
-- 7. Future-proofed for public usernames and sharing features

