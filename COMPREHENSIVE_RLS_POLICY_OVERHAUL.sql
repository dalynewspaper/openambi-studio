-- COMPREHENSIVE RLS POLICY OVERHAUL FOR USER_RECORDINGS
-- This script completely rebuilds all RLS policies and functions for user_recordings
-- Run this in Supabase SQL Editor to fix all policy issues

-- ============================================================================
-- STEP 1: DROP ALL EXISTING POLICIES AND FUNCTIONS
-- ============================================================================

-- Drop all existing policies
DROP POLICY IF EXISTS "Users can view own recordings" ON user_recordings;
DROP POLICY IF EXISTS "Users can insert own recordings" ON user_recordings;
DROP POLICY IF EXISTS "Users can update own recordings" ON user_recordings;
DROP POLICY IF EXISTS "Users can delete own recordings" ON user_recordings;
DROP POLICY IF EXISTS "Authenticated users can view own recordings" ON user_recordings;
DROP POLICY IF EXISTS "Authenticated users can insert own recordings" ON user_recordings;
DROP POLICY IF EXISTS "Authenticated users can update own recordings" ON user_recordings;
DROP POLICY IF EXISTS "Authenticated users can delete own recordings" ON user_recordings;

-- Drop existing triggers first (they depend on functions)
DROP TRIGGER IF EXISTS trigger_set_user_id ON user_recordings;
DROP TRIGGER IF EXISTS update_user_recordings_updated_at ON user_recordings;

-- Drop existing functions
-- Drop ALL versions of insert_user_recording (there may be multiple with different parameter orders)
DROP FUNCTION IF EXISTS insert_user_recording CASCADE;
DROP FUNCTION IF EXISTS update_user_recording(uuid, text, text, text, text);
DROP FUNCTION IF EXISTS delete_user_recording(uuid);
DROP FUNCTION IF EXISTS set_user_id_from_auth() CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;

-- ============================================================================
-- STEP 2: ENSURE TABLE HAS REQUIRED COLUMNS
-- ============================================================================

-- Add deleted_at column if it doesn't exist (for soft delete support)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'user_recordings' 
          AND column_name = 'deleted_at'
    ) THEN
        ALTER TABLE user_recordings ADD COLUMN deleted_at TIMESTAMP WITH TIME ZONE;
        RAISE NOTICE 'Added deleted_at column to user_recordings';
    ELSE
        RAISE NOTICE 'deleted_at column already exists in user_recordings';
    END IF;
END $$;

-- Add duration_seconds column if it doesn't exist (for duration storage)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'user_recordings' 
          AND column_name = 'duration_seconds'
    ) THEN
        ALTER TABLE user_recordings ADD COLUMN duration_seconds INTEGER;
        RAISE NOTICE 'Added duration_seconds column to user_recordings';
    ELSE
        RAISE NOTICE 'duration_seconds column already exists in user_recordings';
    END IF;
END $$;

-- Add icon column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'user_recordings' 
          AND column_name = 'icon'
    ) THEN
        ALTER TABLE user_recordings ADD COLUMN icon TEXT;
        RAISE NOTICE 'Added icon column to user_recordings';
    ELSE
        RAISE NOTICE 'icon column already exists in user_recordings';
    END IF;
END $$;

-- Add updated_at column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'user_recordings' 
          AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE user_recordings ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
        -- Set updated_at = created_at for existing records
        UPDATE user_recordings 
        SET updated_at = created_at 
        WHERE updated_at IS NULL AND created_at IS NOT NULL;
        RAISE NOTICE 'Added updated_at column to user_recordings';
    ELSE
        RAISE NOTICE 'updated_at column already exists in user_recordings';
    END IF;
END $$;

-- Add created_at column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'user_recordings' 
          AND column_name = 'created_at'
    ) THEN
        ALTER TABLE user_recordings ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
        -- Set created_at = NOW() for existing records that don't have it
        UPDATE user_recordings 
        SET created_at = NOW() 
        WHERE created_at IS NULL;
        RAISE NOTICE 'Added created_at column to user_recordings';
    ELSE
        RAISE NOTICE 'created_at column already exists in user_recordings';
    END IF;
END $$;

-- ============================================================================
-- STEP 3: ENSURE RLS IS ENABLED
-- ============================================================================

ALTER TABLE user_recordings ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- STEP 4: CREATE COMPREHENSIVE RLS POLICIES
-- ============================================================================

-- SELECT: Users can only view their own non-deleted recordings
-- Note: We check deleted_at IS NULL to exclude soft-deleted records
-- Added explicit NULL check for auth.uid() to ensure it's set before comparison
CREATE POLICY "Users can view own recordings" ON user_recordings
    FOR SELECT 
    USING (
        auth.uid() IS NOT NULL AND
        auth.uid() = user_id AND
        deleted_at IS NULL
    );

-- INSERT: Users can only insert recordings with their own user_id
CREATE POLICY "Users can insert own recordings" ON user_recordings
    FOR INSERT 
    WITH CHECK (
        auth.uid() = user_id
    );

-- UPDATE: Users can only update their own non-deleted recordings
CREATE POLICY "Users can update own recordings" ON user_recordings
    FOR UPDATE 
    USING (
        auth.uid() = user_id AND
        deleted_at IS NULL
    )
    WITH CHECK (
        auth.uid() = user_id AND
        deleted_at IS NULL
    );

-- DELETE: Users can only delete their own recordings (hard delete)
-- Note: We'll use a function for soft delete instead
CREATE POLICY "Users can delete own recordings" ON user_recordings
    FOR DELETE 
    USING (
        auth.uid() = user_id
    );

-- ============================================================================
-- STEP 5: RECREATE TRIGGER FUNCTIONS
-- ============================================================================

-- Function to automatically set user_id from auth.uid() on INSERT
CREATE OR REPLACE FUNCTION set_user_id_from_auth()
RETURNS TRIGGER AS $$
BEGIN
    -- Always set user_id from auth.uid() to prevent RLS violations
    NEW.user_id = auth.uid();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate triggers
CREATE TRIGGER trigger_set_user_id
    BEFORE INSERT ON user_recordings
    FOR EACH ROW
    EXECUTE FUNCTION set_user_id_from_auth();

CREATE TRIGGER update_user_recordings_updated_at
    BEFORE UPDATE ON user_recordings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- STEP 6: CREATE SECURITY DEFINER FUNCTIONS FOR RELIABLE OPERATIONS
-- ============================================================================

-- Function to insert user recording (bypasses RLS with SECURITY DEFINER)
-- IMPORTANT: Parameter order must be consistent to avoid PostgREST function overloading issues
-- Order: id, file_path, duration_seconds, name, category, description, icon, location_name, latitude, longitude
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
        longitude
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
        p_longitude
    );
    
    RETURN p_id;
END;
$$;

-- Function to update user recording (bypasses RLS with SECURITY DEFINER)
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
    
    -- First check if recording exists at all
    -- Use explicit UUID comparison - SECURITY DEFINER should bypass RLS
    SELECT user_id, deleted_at INTO v_recording_user_id, v_deleted_at
    FROM user_recordings
    WHERE id = p_id;
    
    -- Check if recording was found
    IF v_recording_user_id IS NULL THEN
        -- Try text comparison as fallback (in case of UUID format issues)
        SELECT user_id, deleted_at INTO v_recording_user_id, v_deleted_at
        FROM user_recordings
        WHERE id::text = p_id::text;
        
        -- If still not found, raise exception
        IF v_recording_user_id IS NULL THEN
            RAISE EXCEPTION 'Recording not found with id: % (UUID format). Current user: %. Please verify the recording exists and belongs to you.', 
                p_id::text, v_user_id::text;
        END IF;
    END IF;
    
    -- Check if recording is deleted
    IF v_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION 'Recording has been deleted and cannot be updated';
    END IF;
    
    -- Check ownership
    IF v_recording_user_id != v_user_id THEN
        RAISE EXCEPTION 'You can only update your own recordings';
    END IF;
    
    -- Update only provided fields
    -- Note: We need to handle NULL description specially - if p_description is explicitly NULL, we want to set it to NULL
    -- But if it's not provided (DEFAULT NULL), we keep the existing value
    -- Since PostgREST sends NULL as JSON null, we'll treat NULL as "set to null"
    UPDATE user_recordings
    SET
        name = COALESCE(p_name, name),
        category = COALESCE(p_category, category),
        description = p_description,  -- Allow NULL to be set
        icon = COALESCE(p_icon, icon),
        updated_at = NOW()
    WHERE id = p_id AND user_id = v_user_id AND deleted_at IS NULL;
    
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    
    IF v_rows_updated = 0 THEN
        RAISE EXCEPTION 'Failed to update recording - no rows affected';
    END IF;
    
    RETURN p_id;
END;
$$;

-- Function to delete user recording (hard delete with SECURITY DEFINER)
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
BEGIN
    -- Get authenticated user
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User must be authenticated to delete recordings';
    END IF;
    
    -- Get the recording's user_id
    SELECT user_id INTO v_recording_user_id
    FROM user_recordings
    WHERE id = p_id;
    
    IF v_recording_user_id IS NULL THEN
        RAISE EXCEPTION 'Recording not found';
    END IF;
    
    IF v_recording_user_id != v_user_id THEN
        RAISE EXCEPTION 'You can only delete your own recordings';
    END IF;
    
    -- Hard delete the recording
    DELETE FROM user_recordings
    WHERE id = p_id AND user_id = v_user_id;
    
    RETURN p_id;
END;
$$;

-- ============================================================================
-- STEP 7: GRANT PERMISSIONS
-- ============================================================================

-- Grant execute permissions to authenticated and anon roles
-- Parameter order: id, file_path, duration_seconds, name, category, description, icon, location_name, latitude, longitude
GRANT EXECUTE ON FUNCTION insert_user_recording(uuid, text, integer, text, text, text, text, text, double precision, double precision) TO authenticated;
GRANT EXECUTE ON FUNCTION insert_user_recording(uuid, text, integer, text, text, text, text, text, double precision, double precision) TO anon;

GRANT EXECUTE ON FUNCTION update_user_recording(uuid, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION update_user_recording(uuid, text, text, text, text) TO anon;

GRANT EXECUTE ON FUNCTION delete_user_recording(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_user_recording(uuid) TO anon;

-- ============================================================================
-- STEP 8: VERIFY SETUP
-- ============================================================================

-- Check RLS status
SELECT 
    'RLS Status' as check_type,
    tablename,
    CASE WHEN rowsecurity THEN 'ENABLED' ELSE 'DISABLED' END as status
FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'user_recordings';

-- Check policies
SELECT 
    'Policies' as check_type,
    policyname,
    cmd,
    roles
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'user_recordings'
ORDER BY cmd, policyname;

-- Check functions
SELECT 
    'Functions' as check_type,
    proname as function_name,
    CASE WHEN prosecdef THEN 'SECURITY DEFINER' ELSE 'SECURITY INVOKER' END as security_type
FROM pg_proc
WHERE pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
  AND proname IN ('insert_user_recording', 'update_user_recording', 'delete_user_recording')
ORDER BY proname;

-- ============================================================================
-- NOTES:
-- ============================================================================
-- 1. All functions use SECURITY DEFINER to bypass RLS, ensuring they work reliably
-- 2. Functions still check auth.uid() to ensure users can only modify their own data
-- 3. SELECT policy filters out soft-deleted records (deleted_at IS NULL)
-- 4. DELETE policy allows hard deletes (we use a function for better control)
-- 5. UPDATE policy prevents updating soft-deleted records
-- 6. All operations require authentication (auth.uid() IS NOT NULL)

