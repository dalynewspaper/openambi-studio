-- ADD RECORDED_AT COLUMN TO USER_RECORDINGS TABLE
-- This column should exist but might be missing in some database instances

-- Add recorded_at column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'user_recordings' 
          AND column_name = 'recorded_at'
    ) THEN
        ALTER TABLE user_recordings ADD COLUMN recorded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
        RAISE NOTICE 'Added recorded_at column';
    ELSE
        RAISE NOTICE 'recorded_at column already exists';
    END IF;
END $$;

-- Update existing records to set recorded_at = created_at if recorded_at is NULL
UPDATE user_recordings 
SET recorded_at = created_at 
WHERE recorded_at IS NULL AND created_at IS NOT NULL;

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_user_recordings_recorded_at ON user_recordings(recorded_at DESC);

-- Verify the column was added
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'user_recordings'
  AND column_name IN ('recorded_at', 'created_at')
ORDER BY column_name;

