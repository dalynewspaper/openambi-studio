# Supabase Connection Guide

## ✅ Configuration Complete

Your app is now configured to stream audio files from Supabase Storage!

### What's Been Updated:

1. **SupabaseService.swift**
   - ✅ Updated to use `ambient-sounds` storage bucket
   - ✅ Supports both `ambient_sounds` and `audio_tracks` table names
   - ✅ Properly constructs streaming URLs from Supabase Storage
   - ✅ Improved error handling and logging

2. **AudioManager.swift**
   - ✅ Upgraded to use `AVQueuePlayer` for true streaming
   - ✅ Uses `AVPlayerLooper` for seamless looping
   - ✅ Audio starts playing while still downloading (streaming)
   - ✅ Better performance for large audio files

## 📊 Database Table Structure

Your Supabase table should have this structure:

### Option 1: `ambient_sounds` table (recommended)
```sql
CREATE TABLE ambient_sounds (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  file_path TEXT NOT NULL,  -- Path in storage bucket (e.g., "rain.mp3")
  file_size INT,
  duration DOUBLE PRECISION,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Option 2: `audio_tracks` table (also supported)
```sql
CREATE TABLE audio_tracks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  icon TEXT NOT NULL,
  description TEXT,
  audio_url TEXT NOT NULL,  -- Full URL or path
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

## 🗂️ Storage Bucket Setup

1. **Bucket Name**: `ambient-sounds` (must match exactly)
2. **Public Access**: ✅ Must be public for streaming
3. **File Upload**: Upload your MP3 files to this bucket

### Storage URL Format:
```
https://zrczvgwexppvgxjxzdjw.supabase.co/storage/v1/object/public/ambient-sounds/[filename].mp3
```

## 🔧 How It Works

1. **Fetching Tracks**: The app queries your Supabase table for audio tracks
2. **URL Construction**: If `file_path` is just a filename (e.g., "rain.mp3"), it constructs the full storage URL
3. **Streaming**: Uses `AVQueuePlayer` to stream audio directly from Supabase Storage
4. **Looping**: `AVPlayerLooper` ensures seamless infinite looping

## 🧪 Testing

1. **Check Console Logs**: 
   - ✅ Success: "Successfully fetched X tracks from 'ambient_sounds' table"
   - ✅ Loaded: "Loaded track: [name] from [url]"
   - ❌ Errors: Will show specific error messages

2. **Verify Storage Access**:
   - Open: https://supabase.com/dashboard/project/zrczvgwexppvgxjxzdjw/storage/files/buckets/ambient-sounds
   - Ensure files are uploaded and bucket is public

3. **Test Audio Playback**:
   - Build and run the app
   - Tracks should load from Supabase
   - Audio should stream and play smoothly

## 📝 Example Database Entry

```sql
INSERT INTO ambient_sounds (name, category, file_path) VALUES
  ('Rain', 'nature', 'rain.mp3'),
  ('Ocean Waves', 'nature', 'ocean-waves.mp3'),
  ('Fireplace', 'indoor', 'fireplace.mp3');
```

The `file_path` can be:
- Just the filename: `"rain.mp3"` → Auto-constructs full URL
- Full URL: `"https://..."` → Uses as-is

## 🔍 Troubleshooting

### No tracks loading:
- ✅ Check that your table exists and has data
- ✅ Verify RLS policies allow public read access
- ✅ Check Xcode console for error messages
- ✅ Ensure table name is `ambient_sounds` or `audio_tracks`

### Audio not playing:
- ✅ Verify storage bucket `ambient-sounds` exists and is public
- ✅ Check that file paths in database match actual filenames
- ✅ Ensure audio files are valid MP3 format
- ✅ Check network connectivity

### Streaming issues:
- ✅ Large files (>10MB) may take time to buffer
- ✅ Check internet connection speed
- ✅ Verify Supabase Storage is accessible

## 🚀 Next Steps

1. **Upload Audio Files**: Add your MP3 files to the `ambient-sounds` bucket
2. **Add Database Entries**: Insert records into your `ambient_sounds` table
3. **Test**: Run the app and verify tracks load and play
4. **Monitor**: Check Xcode console for any errors or warnings

---

**Note**: The app will automatically fall back to sample data if Supabase connection fails, so you can test the UI even without a backend connection.

