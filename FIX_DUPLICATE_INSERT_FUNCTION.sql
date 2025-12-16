-- FIX DUPLICATE INSERT FUNCTION
-- There are two versions of insert_user_recording with different parameter orders
-- This causes PostgREST to fail with "Could not choose the best candidate function"
-- We need to drop all versions and create one with a consistent parameter order

-- Drop ALL versions of insert_user_recording using a dynamic approach
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

-- Create a single version with consistent parameter order
-- Order: id, file_path, duration_seconds, name, category, description, icon, location_name, latitude, longitude
CREATE OR REPLACE FUNCTION insert_user_recording(
    p_id uuid,
    p_file_path text,
    p_duration_seconds integer DEFAULT NULL,
    p_name text DEFAULT NULL,
    p_category text DEFAULT NULL,
    p_description text DEFAULT NULL,
    p_icon text DEFAULT NULL,
    p_location_name text DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_longitude double precision DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id uuid;
    v_name text;
BEGIN
    -- Get authenticated user
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User must be authenticated to insert recordings';
    END IF;
    
    -- Generate default name if not provided
    v_name := COALESCE(p_name, 'Recording - ' || to_char(NOW(), 'HH24:MI'));
    
    -- Insert the recording
    INSERT INTO user_recordings (
        id,
        user_id,
        file_path,
        duration_seconds,
        name,
        category,
        description,
        icon,
        location_name,
        latitude,
        longitude
    ) VALUES (
        p_id,
        v_user_id,
        p_file_path,
        p_duration_seconds,
        v_name,
        COALESCE(p_category, 'My Recordings'),
        p_description,
        COALESCE(p_icon, 'waveform'),
        p_location_name,
        p_latitude,
        p_longitude
    );
    
    RETURN p_id;
END;
$$;

-- Grant execute permissions (matching the new parameter order)
GRANT EXECUTE ON FUNCTION insert_user_recording(uuid, text, integer, text, text, text, text, text, double precision, double precision) TO authenticated;
GRANT EXECUTE ON FUNCTION insert_user_recording(uuid, text, integer, text, text, text, text, text, double precision, double precision) TO anon;

-- Verify only one version exists
SELECT 
    'Function Verification' as check_type,
    proname as function_name,
    pg_get_function_arguments(oid) as arguments,
    CASE WHEN prosecdef THEN 'SECURITY DEFINER' ELSE 'SECURITY INVOKER' END as security_type
FROM pg_proc
WHERE pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
  AND proname = 'insert_user_recording'
ORDER BY proname;

