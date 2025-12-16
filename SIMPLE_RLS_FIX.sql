-- Simple RLS Fix: Allow authenticated users to insert with matching user_id
-- This is the standard Supabase pattern - send user_id matching auth.uid()

-- Drop the existing INSERT policy
DROP POLICY IF EXISTS "Users can insert own recordings" ON user_recordings;

-- Create policy that allows insert when user_id matches auth.uid()
-- This is what PostgREST validates against the payload
CREATE POLICY "Users can insert own recordings" ON user_recordings
    FOR INSERT 
    TO authenticated
    WITH CHECK (auth.uid() = user_id);  -- user_id in payload must match auth.uid()

-- Verify the policy
SELECT 
    policyname,
    cmd,
    roles,
    with_check
FROM pg_policies
WHERE tablename = 'user_recordings' AND cmd = 'INSERT';

