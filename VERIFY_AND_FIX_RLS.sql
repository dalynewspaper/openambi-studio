-- Verify and Fix RLS Policy for user_recordings
-- Run this to check current policies and fix if needed

-- Step 1: Check current INSERT policies
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'user_recordings' AND cmd = 'INSERT';

-- Step 2: Drop ALL existing INSERT policies to start fresh
DROP POLICY IF EXISTS "Users can insert own recordings" ON user_recordings;
DROP POLICY IF EXISTS "Users can insert own recordings" ON public.user_recordings;

-- Step 3: Create a simpler policy that just checks if user_id matches auth.uid()
-- The trigger will ensure user_id is always set to auth.uid(), so this should always pass
CREATE POLICY "Users can insert own recordings" ON user_recordings
    FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

-- Step 4: Verify the trigger function exists and is correct
SELECT 
    proname as function_name,
    prosecdef as is_security_definer,
    prosrc as function_body
FROM pg_proc
WHERE proname = 'set_user_id_from_auth';

-- Step 5: Verify the trigger exists
SELECT 
    trigger_name, 
    event_manipulation, 
    event_object_table,
    action_timing,
    action_statement
FROM information_schema.triggers
WHERE event_object_table = 'user_recordings' AND trigger_name = 'trigger_set_user_id';

-- Expected results:
-- 1. Should show the INSERT policy with WITH CHECK (auth.uid() = user_id)
-- 2. Should show the function exists and is SECURITY DEFINER (is_security_definer = true)
-- 3. Should show the trigger exists with action_timing = 'BEFORE'

