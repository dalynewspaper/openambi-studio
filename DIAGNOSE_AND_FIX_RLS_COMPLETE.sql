-- COMPREHENSIVE DIAGNOSTIC AND FIX FOR RLS ISSUES
-- This will show you what's wrong and fix it
-- Run this entire script in your Supabase SQL Editor

-- ============================================================================
-- PART 1: DIAGNOSTIC - Check Current State
-- ============================================================================

-- Check current RLS policies with full details
SELECT 
    'Current Policies' as section,
    policyname,
    cmd,
    qual as using_clause,
    with_check as with_check_clause
FROM pg_policies
WHERE tablename = 'user_recordings'
ORDER BY cmd, policyname;

-- Check if insert_user_recording function exists and its signature
SELECT 
    'INSERT Function Check' as section,
    proname,
    pg_get_function_arguments(oid) as arguments,
    prosecdef as is_security_definer
FROM pg_proc
WHERE proname = 'insert_user_recording'
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

-- ============================================================================
-- PART 2: FIX - Recreate Everything Correctly
-- ============================================================================

-- Step 1: Fix the trigger function
CREATE OR REPLACE FUNCTION set_user_id_from_auth()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public, pg_temp
LANGUAGE plpgsql
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'User must be authenticated to insert recordings';
    END IF;
    
    -- CRITICAL: Force set user_id - this must happen BEFORE RLS policy check
    NEW.user_id := auth.uid();
    
    -- Set defaults
    IF NEW.name IS NULL OR NEW.name = '' THEN
        NEW.name := 'Recording - ' || to_char(NOW(), 'HH24:MI');
    END IF;
    
    IF NEW.category IS NULL OR NEW.category = '' THEN
        NEW.category := 'My Recordings';
    END IF;
    
    IF NEW.icon IS NULL OR NEW.icon = '' THEN
        NEW.icon := 'waveform';
    END IF;
    
    NEW.deleted_at := NULL;
    
    IF NEW.created_at IS NULL THEN
        NEW.created_at := NOW();
    END IF;
    
    IF NEW.updated_at IS NULL THEN
        NEW.updated_at := NOW();
    END IF;
    
    RETURN NEW;
END;
$$;

-- Step 2: Ensure trigger exists
DROP TRIGGER IF EXISTS trigger_set_user_id ON user_recordings;
CREATE TRIGGER trigger_set_user_id
    BEFORE INSERT ON user_recordings
    FOR EACH ROW
    EXECUTE FUNCTION set_user_id_from_auth();

-- Step 3: Fix RLS SELECT Policy (MOST CRITICAL FOR VISIBILITY)
DROP POLICY IF EXISTS "Users can view own recordings" ON user_recordings;

-- This policy must allow users to see records where:
-- 1. They are authenticated (auth.uid() IS NOT NULL)
-- 2. The user_id matches their auth.uid()
-- 3. The record is not soft-deleted (deleted_at IS NULL)
CREATE POLICY "Users can view own recordings" ON user_recordings
    FOR SELECT 
    USING (
        auth.uid() IS NOT NULL
        AND auth.uid() = user_id
        AND deleted_at IS NULL
    );

-- Step 4: Fix RLS INSERT Policy
DROP POLICY IF EXISTS "Users can insert own recordings" ON user_recordings;

-- The trigger sets user_id = auth.uid() BEFORE this policy check
-- So we need to allow inserts where user_id will match after trigger runs
CREATE POLICY "Users can insert own recordings" ON user_recordings
    FOR INSERT 
    WITH CHECK (
        auth.uid() IS NOT NULL
        -- After trigger runs, user_id will equal auth.uid()
        -- But we allow NULL here because trigger will set it
        AND (auth.uid() = user_id OR user_id IS NULL)
    );

-- Step 5: Fix RLS UPDATE Policy
DROP POLICY IF EXISTS "Users can update own recordings" ON user_recordings;

CREATE POLICY "Users can update own recordings" ON user_recordings
    FOR UPDATE 
    USING (
        auth.uid() IS NOT NULL
        AND auth.uid() = user_id
        AND deleted_at IS NULL
    )
    WITH CHECK (
        auth.uid() IS NOT NULL
        AND auth.uid() = user_id
        AND deleted_at IS NULL
    );

-- Step 6: Fix RLS DELETE Policy (for soft delete via UPDATE)
DROP POLICY IF EXISTS "Users can delete own recordings" ON user_recordings;

CREATE POLICY "Users can delete own recordings" ON user_recordings
    FOR DELETE 
    USING (
        auth.uid() IS NOT NULL
        AND auth.uid() = user_id
    );

-- ============================================================================
-- PART 3: VERIFY THE FIX
-- ============================================================================

-- Show all policies after fix
SELECT 
    'Policies After Fix' as section,
    policyname,
    cmd,
    qual as using_clause,
    with_check as with_check_clause
FROM pg_policies
WHERE tablename = 'user_recordings'
ORDER BY cmd, policyname;

-- Show trigger
SELECT 
    'Trigger After Fix' as section,
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers
WHERE event_object_table = 'user_recordings'
  AND trigger_name = 'trigger_set_user_id';

-- ============================================================================
-- EXPECTED RESULTS:
-- ============================================================================
-- After running this:
-- 1. SELECT policy should show: auth.uid() IS NOT NULL AND auth.uid() = user_id AND deleted_at IS NULL
-- 2. INSERT policy should show: auth.uid() IS NOT NULL AND (auth.uid() = user_id OR user_id IS NULL)
-- 3. Trigger should exist with BEFORE INSERT timing
-- 4. New recordings should be visible immediately after insertion
-- 5. Updates and deletes should persist correctly
