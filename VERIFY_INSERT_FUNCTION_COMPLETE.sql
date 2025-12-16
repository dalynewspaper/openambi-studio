-- VERIFY INSERT FUNCTION HAS ALL PARAMETERS
-- Check that the function has the correct signature with all 10 parameters

SELECT 
    'Function Signature Check' as check_type,
    proname as function_name,
    pronargs as parameter_count,
    pg_get_function_arguments(oid) as arguments,
    oid::regprocedure as full_signature
FROM pg_proc
WHERE pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
  AND proname = 'insert_user_recording';

-- Expected: 10 parameters
-- p_id, p_file_path, p_duration_seconds, p_name, p_category, p_description, p_icon, p_location_name, p_latitude, p_longitude

-- Also check the function definition
SELECT 
    'Function Definition' as check_type,
    pg_get_functiondef(oid) as function_definition
FROM pg_proc
WHERE pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
  AND proname = 'insert_user_recording'
LIMIT 1;

