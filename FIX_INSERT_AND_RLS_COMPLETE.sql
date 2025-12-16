-- COMPREHENSIVE FIX FOR INSERT FUNCTION AND RLS POLICIES
-- This ensures new recordings are visible immediately after insertion
-- Run this in your Supabase SQL Editor

-- ============================================================================
-- STEP 1: VERIFY AND FIX THE INSERT TRIGGER FUNCTION
-- ============================================================================

-- Ensure the trigger function correctly sets user_id and has SECURITY DEFINER
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
    -- This ensures RLS policies will work correctly
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

-- ============================================================================
-- STEP 2: ENSURE TRIGGER EXISTS AND IS CORRECT
-- ============================================================================

DROP TRIGGER IF EXISTS trigger_set_user_id ON user_recordings;

CREATE TRIGGER trigger_set_user_id
    BEFORE INSERT ON user_recordings
    FOR EACH ROW
    EXECUTE FUNCTION set_user_id_from_auth();

-- ============================================================================
-- STEP 3: FIX RLS SELECT POLICY
-- ============================================================================

-- Drop existing SELECT policy
DROP POLICY IF EXISTS "Users can view own recordings" ON user_recordings;

-- Create SELECT policy that works with the trigger
-- The trigger ensures user_id = auth.uid(), so this should always pass
CREATE POLICY "Users can view own recordings" ON user_recordings
    FOR SELECT 
    USING (
        -- User must be authenticated
        auth.uid() IS NOT NULL
        AND
        -- User can only see their own recordings
        auth.uid() = user_id
        AND
        -- Exclude soft-deleted recordings
        deleted_at IS NULL
    );

-- ============================================================================
-- STEP 4: FIX RLS INSERT POLICY
-- ============================================================================

-- Drop existing INSERT policy
DROP POLICY IF EXISTS "Users can insert own recordings" ON user_recordings;

-- Create INSERT policy that works with the trigger
-- The trigger will set user_id = auth.uid() BEFORE the policy check
-- So we just need to verify the user is authenticated
CREATE POLICY "Users can insert own recordings" ON user_recordings
    FOR INSERT 
    WITH CHECK (
        -- User must be authenticated
        auth.uid() IS NOT NULL
        AND
        -- After trigger runs, user_id will equal auth.uid()
        -- But we check it here too for safety
        (auth.uid() = user_id OR user_id IS NULL)
    );

-- ============================================================================
-- STEP 5: VERIFY INSERT FUNCTION EXISTS AND IS CORRECT
-- ============================================================================

-- Check if insert_user_recording function exists
SELECT 
    'Function Check' as check_type,
    proname as function_name,
    prosecdef as is_security_definer,
    pg_get_function_arguments(oid) as arguments
FROM pg_proc
WHERE proname = 'insert_user_recording'
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

-- ============================================================================
-- STEP 6: TEST THE SETUP
-- ============================================================================

-- Verify trigger exists
SELECT 
    'Trigger Check' as check_type,
    trigger_name,
    event_manipulation,
    event_object_table,
    action_timing,
    action_statement
FROM information_schema.triggers
WHERE event_object_table = 'user_recordings'
  AND trigger_name = 'trigger_set_user_id';

-- Verify RLS policies
SELECT 
    'Policy Check' as check_type,
    policyname,
    cmd,
    qual as using_clause,
    with_check as with_check_clause
FROM pg_policies
WHERE tablename = 'user_recordings'
ORDER BY cmd, policyname;

-- ============================================================================
-- EXPECTED RESULTS:
-- ============================================================================
-- 1. trigger_set_user_id trigger should exist with BEFORE INSERT timing
-- 2. SELECT policy should check: auth.uid() IS NOT NULL AND auth.uid() = user_id AND deleted_at IS NULL
-- 3. INSERT policy should check: auth.uid() IS NOT NULL AND (auth.uid() = user_id OR user_id IS NULL)
-- 4. insert_user_recording function should exist with SECURITY DEFINER
--
-- If all of these are correct, new recordings should be visible immediately after insertion
