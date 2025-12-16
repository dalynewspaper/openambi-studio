-- DROP ALL VERSIONS OF insert_user_recording
-- This script drops all versions explicitly by their full signature

-- First, let's see what we have
DO $$
DECLARE
    func_record RECORD;
BEGIN
    FOR func_record IN 
        SELECT oid::regprocedure as func_sig
        FROM pg_proc
        WHERE pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
          AND proname = 'insert_user_recording'
    LOOP
        RAISE NOTICE 'Dropping function: %', func_record.func_sig;
        EXECUTE 'DROP FUNCTION IF EXISTS ' || func_record.func_sig || ' CASCADE';
    END LOOP;
END $$;

-- Verify all are dropped
SELECT 
    'Verification' as check_type,
    COUNT(*) as remaining_functions,
    CASE 
        WHEN COUNT(*) = 0 THEN '✅ All functions dropped'
        ELSE '❌ Still have ' || COUNT(*) || ' function(s)'
    END as status
FROM pg_proc
WHERE pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
  AND proname = 'insert_user_recording';

