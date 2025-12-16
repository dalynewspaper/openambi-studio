-- LIST ALL VERSIONS OF insert_user_recording
-- This will show all function signatures so we can drop them explicitly

SELECT 
    'Function Versions' as check_type,
    proname as function_name,
    pg_get_function_arguments(oid) as arguments,
    oid::regprocedure as full_signature
FROM pg_proc
WHERE pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
  AND proname = 'insert_user_recording'
ORDER BY proname, oid;

