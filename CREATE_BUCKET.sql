-- Quick Setup: Create user-recordings bucket
-- Run this in Supabase SQL Editor: https://supabase.com/dashboard → SQL Editor

-- Step 1: Create the bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'user-recordings',
    'user-recordings',
    false,  -- Private bucket
    52428800,  -- 50 MB file size limit
    ARRAY['audio/m4a', 'audio/mpeg', 'audio/x-m4a']
)
ON CONFLICT (id) DO NOTHING;

-- Step 2: Set up storage policies (users can only access their own files)
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

-- Verify bucket was created
SELECT 
    id, 
    name, 
    public, 
    file_size_limit,
    allowed_mime_types
FROM storage.buckets 
WHERE id = 'user-recordings';

-- Expected result: Should show one row with the bucket details

