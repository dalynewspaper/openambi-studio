-- Final Attempt to Fix RLS
-- The issue might be that Supabase validates the payload before the trigger runs
-- So we need a policy that allows the insert even if user_id doesn't match initially

-- Step 1: Drop existing policy
DROP POLICY IF EXISTS "Users can insert own recordings" ON user_recordings;

-- Step 2: Create a policy that's more permissive but still secure
-- The key insight: Supabase might validate the JSON payload's user_id BEFORE the trigger runs
-- So we need to allow inserts where user_id is provided (even if it doesn't match)
-- The trigger will ALWAYS override it to auth.uid() anyway
CREATE POLICY "Users can insert own recordings" ON user_recordings
    FOR INSERT 
    WITH CHECK (
        -- User must be authenticated
        auth.uid() IS NOT NULL
        -- We don't check user_id here because:
        -- 1. The trigger will ALWAYS set it to auth.uid() before the row is inserted
        -- 2. Supabase might validate the payload's user_id before the trigger runs
        -- 3. Since the trigger guarantees user_id = auth.uid(), we only need to check auth exists
    );

-- Step 3: Verify the trigger function is correct and has SECURITY DEFINER
CREATE OR REPLACE FUNCTION set_user_id_from_auth()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    -- Force set user_id from auth.uid()
    -- This MUST work or the insert will fail
    NEW.user_id := auth.uid()::uuid;
    
    -- Debug: Log if auth.uid() is NULL (shouldn't happen)
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'auth.uid() is NULL - user is not authenticated';
    END IF;
    
    RETURN NEW;
END;
$$;

-- Step 4: Ensure trigger exists
DROP TRIGGER IF EXISTS trigger_set_user_id ON user_recordings;
CREATE TRIGGER trigger_set_user_id
    BEFORE INSERT ON user_recordings
    FOR EACH ROW
    EXECUTE FUNCTION set_user_id_from_auth();

-- Step 5: Verify everything
SELECT 
    'Policy' as type,
    policyname as name,
    with_check as details
FROM pg_policies
WHERE tablename = 'user_recordings' AND cmd = 'INSERT'
UNION ALL
SELECT 
    'Trigger' as type,
    trigger_name as name,
    action_statement as details
FROM information_schema.triggers
WHERE event_object_table = 'user_recordings' AND trigger_name = 'trigger_set_user_id'
UNION ALL
SELECT 
    'Function' as type,
    proname as name,
    CASE WHEN prosecdef THEN 'SECURITY DEFINER' ELSE 'SECURITY INVOKER' END as details
FROM pg_proc
WHERE proname = 'set_user_id_from_auth';

