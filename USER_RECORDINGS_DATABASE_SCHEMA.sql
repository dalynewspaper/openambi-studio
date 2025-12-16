-- User Recordings Database Schema
-- Run this SQL in your Supabase SQL Editor to create the user_recordings table

-- Create the user_recordings table
CREATE TABLE IF NOT EXISTS user_recordings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Core audio data
    file_path TEXT NOT NULL,  -- Path in storage: "{user_id}/{id}.m4a"
    file_size BIGINT,          -- File size in bytes
    duration DOUBLE PRECISION,  -- Duration in seconds
    
    -- User-provided metadata
    name TEXT NOT NULL,        -- User-entered or auto-generated title
    category TEXT,              -- User-selected category
    description TEXT,           -- Optional user description
    
    -- Automatic metadata
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Location data (optional)
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    location_name TEXT,         -- Reverse geocoded location name
    
    -- Audio analysis metadata
    average_level DOUBLE PRECISION,  -- Average audio level (0.0-1.0)
    peak_level DOUBLE PRECISION,     -- Peak audio level (0.0-1.0)
    
    -- Playback metadata
    play_count INTEGER DEFAULT 0,
    last_played_at TIMESTAMP WITH TIME ZONE,
    
    -- Soft delete
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_recordings_user_id ON user_recordings(user_id);
CREATE INDEX IF NOT EXISTS idx_user_recordings_category ON user_recordings(category);
CREATE INDEX IF NOT EXISTS idx_user_recordings_recorded_at ON user_recordings(recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_recordings_location ON user_recordings(latitude, longitude) WHERE latitude IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_user_recordings_deleted_at ON user_recordings(deleted_at) WHERE deleted_at IS NULL;

-- Enable Row Level Security (RLS)
ALTER TABLE user_recordings ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (for clean setup)
DROP POLICY IF EXISTS "Users can view own recordings" ON user_recordings;
DROP POLICY IF EXISTS "Users can insert own recordings" ON user_recordings;
DROP POLICY IF EXISTS "Users can update own recordings" ON user_recordings;
DROP POLICY IF EXISTS "Users can delete own recordings" ON user_recordings;

-- Users can only see their own recordings (excluding soft-deleted)
CREATE POLICY "Users can view own recordings" ON user_recordings
    FOR SELECT 
    USING (auth.uid() = user_id AND deleted_at IS NULL);

-- Users can insert their own recordings
CREATE POLICY "Users can insert own recordings" ON user_recordings
    FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

-- Users can update their own recordings (excluding soft-deleted)
CREATE POLICY "Users can update own recordings" ON user_recordings
    FOR UPDATE 
    USING (auth.uid() = user_id AND deleted_at IS NULL);

-- Users can delete their own recordings (soft delete)
CREATE POLICY "Users can delete own recordings" ON user_recordings
    FOR DELETE 
    USING (auth.uid() = user_id);

-- Create function to automatically set user_id from auth.uid()
-- This ensures RLS compliance by always matching the authenticated user
CREATE OR REPLACE FUNCTION set_user_id_from_auth()
RETURNS TRIGGER AS $$
BEGIN
    -- Always set user_id from auth.uid() to prevent RLS violations
    NEW.user_id = auth.uid();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to automatically set user_id on INSERT
DROP TRIGGER IF EXISTS trigger_set_user_id ON user_recordings;
CREATE TRIGGER trigger_set_user_id
    BEFORE INSERT ON user_recordings
    FOR EACH ROW
    EXECUTE FUNCTION set_user_id_from_auth();

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update updated_at
DROP TRIGGER IF EXISTS update_user_recordings_updated_at ON user_recordings;
CREATE TRIGGER update_user_recordings_updated_at
    BEFORE UPDATE ON user_recordings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Storage bucket setup instructions:
-- 1. Go to Supabase Dashboard → Storage
-- 2. Create a new bucket named "user-recordings"
-- 3. Set it to Private (not public)
-- 4. Run the storage policies below

-- Storage bucket policies (run in Supabase SQL Editor after creating bucket)
-- Note: Replace 'user-recordings' with your actual bucket name if different

-- Users can upload to their own folder
CREATE POLICY IF NOT EXISTS "Users can upload own recordings" ON storage.objects
    FOR INSERT 
    WITH CHECK (
        bucket_id = 'user-recordings' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );

-- Users can read their own recordings
CREATE POLICY IF NOT EXISTS "Users can read own recordings" ON storage.objects
    FOR SELECT 
    USING (
        bucket_id = 'user-recordings' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );

-- Users can update their own recordings
CREATE POLICY IF NOT EXISTS "Users can update own recordings" ON storage.objects
    FOR UPDATE 
    USING (
        bucket_id = 'user-recordings' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );

-- Users can delete their own recordings
CREATE POLICY IF NOT EXISTS "Users can delete own recordings" ON storage.objects
    FOR DELETE 
    USING (
        bucket_id = 'user-recordings' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );

