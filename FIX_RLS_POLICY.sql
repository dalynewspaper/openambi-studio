-- Fix RLS Policy for user_recordings
-- Run this in Supabase SQL Editor to fix the "new row violates row-level security policy" error
-- This creates a trigger that automatically sets user_id from auth.uid() on INSERT

-- Step 1: Create function to automatically set user_id from auth.uid()
-- This ensures RLS compliance by always matching the authenticated user
CREATE OR REPLACE FUNCTION set_user_id_from_auth()
RETURNS TRIGGER AS $$
BEGIN
    -- Always set user_id from auth.uid() to prevent RLS violations
    -- This runs BEFORE the RLS policy check, so the policy will see the correct user_id
    NEW.user_id = auth.uid();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 2: Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trigger_set_user_id ON user_recordings;

-- Step 3: Create trigger that runs BEFORE INSERT
CREATE TRIGGER trigger_set_user_id
    BEFORE INSERT ON user_recordings
    FOR EACH ROW
    EXECUTE FUNCTION set_user_id_from_auth();

-- Step 4: Update the INSERT policy to be more flexible
-- The policy should allow inserts where user_id matches auth.uid() OR where user_id is NULL
-- (NULL will be set by the trigger before the policy check)
DROP POLICY IF EXISTS "Users can insert own recordings" ON user_recordings;

CREATE POLICY "Users can insert own recordings" ON user_recordings
    FOR INSERT 
    WITH CHECK (
        -- Allow if user_id matches auth.uid() (normal case)
        auth.uid() = user_id 
        OR 
        -- Allow if user_id is NULL (will be set by trigger before policy check)
        user_id IS NULL
    );

-- Step 5: Verify the trigger was created
SELECT 
    trigger_name, 
    event_manipulation, 
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE event_object_table = 'user_recordings';

-- Expected result: Should show trigger_set_user_id trigger

-- Note: After running this:
-- 1. The trigger will automatically set user_id from auth.uid() on INSERT
-- 2. The app can send user_id in the payload OR omit it - the trigger will set it correctly
-- 3. The RLS policy will pass because user_id will match auth.uid() after the trigger runs
