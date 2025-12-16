-- Final RLS Fix - This should resolve the policy violation
-- Run this entire script in Supabase SQL Editor

-- Step 1: Check what policies currently exist
SELECT 
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'user_recordings';

-- Step 2: Drop ALL existing INSERT policies (there might be duplicates or old ones)
DO $$ 
BEGIN
    -- Drop all INSERT policies
    DROP POLICY IF EXISTS "Users can insert own recordings" ON user_recordings;
    DROP POLICY IF EXISTS "Users can insert own recordings" ON public.user_recordings;
    
    -- Also try dropping with different case variations
    EXECUTE (
        SELECT string_agg('DROP POLICY IF EXISTS ' || quote_ident(policyname) || ' ON user_recordings;', ' ')
        FROM pg_policies
        WHERE tablename = 'user_recordings' AND cmd = 'INSERT'
    );
EXCEPTION WHEN OTHERS THEN
    -- Ignore errors if policies don't exist
    NULL;
END $$;

-- Step 3: Ensure the trigger function is correct and has SECURITY DEFINER
CREATE OR REPLACE FUNCTION set_user_id_from_auth()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    -- Force set user_id from auth.uid() - this overrides any value sent by client
    NEW.user_id = auth.uid()::uuid;
    RETURN NEW;
END;
$$;

-- Step 4: Ensure trigger exists and is correct
DROP TRIGGER IF EXISTS trigger_set_user_id ON user_recordings;
CREATE TRIGGER trigger_set_user_id
    BEFORE INSERT ON user_recordings
    FOR EACH ROW
    EXECUTE FUNCTION set_user_id_from_auth();

-- Step 5: Create the INSERT policy
-- Since the trigger ALWAYS sets user_id = auth.uid(), the policy just needs to check that
CREATE POLICY "Users can insert own recordings" ON user_recordings
    FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

-- Step 6: Verify everything is set up correctly
SELECT 
    'Policy Check' as check_type,
    policyname,
    cmd,
    with_check
FROM pg_policies
WHERE tablename = 'user_recordings' AND cmd = 'INSERT'
UNION ALL
SELECT 
    'Trigger Check' as check_type,
    trigger_name as policyname,
    event_manipulation as cmd,
    action_statement as with_check
FROM information_schema.triggers
WHERE event_object_table = 'user_recordings' AND trigger_name = 'trigger_set_user_id';

-- Expected: Should show 1 INSERT policy and 1 trigger, both correctly configured

