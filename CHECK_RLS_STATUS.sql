-- Check if RLS is actually disabled on the table
-- Even with 0 policies, if RLS is ENABLED, it will block all operations

SELECT 
    'Table RLS Status' as check_type,
    schemaname,
    tablename,
    rowsecurity as rls_enabled,
    CASE 
        WHEN rowsecurity THEN '❌ RLS IS ENABLED - This will block inserts!'
        ELSE '✅ RLS IS DISABLED - Good!'
    END as status
FROM pg_tables
WHERE tablename = 'user_recordings';

-- If RLS is still enabled, run this to disable it:
-- ALTER TABLE user_recordings DISABLE ROW LEVEL SECURITY;

-- Verify after disabling
SELECT 
    'Verification' as check_type,
    rowsecurity as rls_enabled_after
FROM pg_tables
WHERE tablename = 'user_recordings';

