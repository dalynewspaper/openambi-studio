-- Check the current delete_user_recording function definition
-- This will show us exactly what code is running

SELECT 
    proname as function_name,
    pg_get_functiondef(oid) as function_definition
FROM pg_proc
WHERE proname = 'delete_user_recording'
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');
