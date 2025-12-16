-- FIX USER_RECORDINGS TABLE
-- Add missing columns if they don't exist

-- Step 1: Check current table structure
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'user_recordings'
ORDER BY ordinal_position;

-- Step 2: Add missing columns (only if they don't exist)
-- Add name column
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'user_recordings' 
          AND column_name = 'name'
    ) THEN
        ALTER TABLE user_recordings ADD COLUMN name TEXT;
        RAISE NOTICE 'Added name column';
    ELSE
        RAISE NOTICE 'name column already exists';
    END IF;
END $$;

-- Add category column (if missing)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'user_recordings' 
          AND column_name = 'category'
    ) THEN
        ALTER TABLE user_recordings ADD COLUMN category TEXT;
        RAISE NOTICE 'Added category column';
    ELSE
        RAISE NOTICE 'category column already exists';
    END IF;
END $$;

-- Add description column (if missing)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'user_recordings' 
          AND column_name = 'description'
    ) THEN
        ALTER TABLE user_recordings ADD COLUMN description TEXT;
        RAISE NOTICE 'Added description column';
    ELSE
        RAISE NOTICE 'description column already exists';
    END IF;
END $$;

-- Add location_name column (if missing)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'user_recordings' 
          AND column_name = 'location_name'
    ) THEN
        ALTER TABLE user_recordings ADD COLUMN location_name TEXT;
        RAISE NOTICE 'Added location_name column';
    ELSE
        RAISE NOTICE 'location_name column already exists';
    END IF;
END $$;

-- Add latitude column (if missing)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'user_recordings' 
          AND column_name = 'latitude'
    ) THEN
        ALTER TABLE user_recordings ADD COLUMN latitude DOUBLE PRECISION;
        RAISE NOTICE 'Added latitude column';
    ELSE
        RAISE NOTICE 'latitude column already exists';
    END IF;
END $$;

-- Add longitude column (if missing)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'user_recordings' 
          AND column_name = 'longitude'
    ) THEN
        ALTER TABLE user_recordings ADD COLUMN longitude DOUBLE PRECISION;
        RAISE NOTICE 'Added longitude column';
    ELSE
        RAISE NOTICE 'longitude column already exists';
    END IF;
END $$;

-- Add icon column (if missing)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'user_recordings' 
          AND column_name = 'icon'
    ) THEN
        ALTER TABLE user_recordings ADD COLUMN icon TEXT DEFAULT 'waveform';
        RAISE NOTICE 'Added icon column';
    ELSE
        RAISE NOTICE 'icon column already exists';
    END IF;
END $$;

-- Step 3: Verify final structure
SELECT 
    'Final Table Structure' as check_type,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'user_recordings'
ORDER BY ordinal_position;

