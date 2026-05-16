-- Extend insert_user_recording / update_user_recording to persist video_file_path.
--
-- Run AFTER MIGRATION_VIDEO.sql and BUCKET_VIDEO.sql.
--
-- DROP CASCADE pattern: removes dependent grants alongside the old
-- overload so we recreate them exactly here. If you have multiple
-- insert_user_recording overloads, CASCADE clears them all — recreate
-- only this signature.

DROP FUNCTION IF EXISTS insert_user_recording CASCADE;

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
    p_longitude double precision DEFAULT NULL,
    p_video_file_path text DEFAULT NULL
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
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User must be authenticated to insert recordings';
    END IF;

    v_name := COALESCE(p_name, 'Recording - ' || to_char(NOW(), 'HH24:MI'));

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
        longitude,
        video_file_path,
        deleted_at
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
        p_longitude,
        p_video_file_path,
        NULL
    );

    RETURN p_id;
END;
$$;

GRANT EXECUTE ON FUNCTION insert_user_recording(
  uuid, text, integer, text, text, text, text, text, double precision, double precision, text
) TO authenticated;


-- update_user_recording: optional video path with explicit "no change vs change"
-- sentinel (p_update_video). When p_update_video = false, video_file_path is
-- left untouched; when true, video_file_path is set to p_video_file_path
-- (which may be NULL to clear it).

DROP FUNCTION IF EXISTS update_user_recording(uuid, text, text, text, text);
DROP FUNCTION IF EXISTS update_user_recording(uuid, text, text, text, text, boolean, text);

CREATE OR REPLACE FUNCTION update_user_recording(
    p_id uuid,
    p_name text DEFAULT NULL,
    p_category text DEFAULT NULL,
    p_description text DEFAULT NULL,
    p_icon text DEFAULT NULL,
    p_update_video boolean DEFAULT false,
    p_video_file_path text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id uuid;
    v_recording_user_id uuid;
    v_deleted_at timestamp with time zone;
    v_rows_updated integer;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User must be authenticated to update recordings';
    END IF;

    SELECT user_id, deleted_at
    INTO v_recording_user_id, v_deleted_at
    FROM user_recordings
    WHERE id = p_id;

    IF v_recording_user_id IS NULL THEN
        RAISE EXCEPTION 'Recording not found with id: %. Current user: %.',
            p_id::text, v_user_id::text;
    END IF;

    IF v_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION 'Recording has been deleted and cannot be updated. Recording id: %, deleted_at: %',
            p_id::text, v_deleted_at::text;
    END IF;

    IF v_recording_user_id != v_user_id THEN
        RAISE EXCEPTION 'You can only update your own recordings. Recording belongs to user: %, but you are: %',
            v_recording_user_id::text, v_user_id::text;
    END IF;

    UPDATE user_recordings
    SET
        name = COALESCE(p_name, name),
        category = COALESCE(p_category, category),
        description = p_description,
        icon = COALESCE(p_icon, icon),
        video_file_path = CASE WHEN p_update_video THEN p_video_file_path ELSE video_file_path END,
        updated_at = NOW()
    WHERE id = p_id
      AND user_id = v_user_id
      AND deleted_at IS NULL;

    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

    IF v_rows_updated = 0 THEN
        RAISE EXCEPTION 'Failed to update recording - no rows affected. Recording id: %',
            p_id::text;
    END IF;

    RETURN p_id;
END;
$$;

GRANT EXECUTE ON FUNCTION update_user_recording(
  uuid, text, text, text, text, boolean, text
) TO authenticated;
