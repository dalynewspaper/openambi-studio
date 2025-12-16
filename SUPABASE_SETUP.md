# Supabase Setup Guide

## ✅ Already Configured
- Supabase URL: `https://zrczvgwexppvgxjxzdjw.supabase.co`

## 🔑 Step 1: Get Your Anon Key

1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Select your project (`zrczvgwexppvgxjxzdjw`)
3. Go to **Settings** → **API**
4. Copy the **anon/public** key (starts with `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`)
5. Open `openambi-studio/Config/SupabaseConfig.swift`
6. Replace `YOUR_SUPABASE_ANON_KEY` with your actual key

```swift
static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." // Your actual key here
```

## 📊 Step 2: Create Database Tables

### Create `audio_tracks` table:

1. Go to **SQL Editor** in Supabase
2. Run this SQL:

```sql
-- Create audio_tracks table
CREATE TABLE IF NOT EXISTS audio_tracks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('nature', 'indoor')),
  icon TEXT NOT NULL,
  description TEXT,
  audio_url TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security (RLS)
ALTER TABLE audio_tracks ENABLE ROW LEVEL SECURITY;

-- Create policy to allow public read access
CREATE POLICY "Allow public read access" ON audio_tracks
  FOR SELECT USING (true);

-- Insert sample data (optional)
INSERT INTO audio_tracks (name, category, icon, description, audio_url) VALUES
  ('Rain', 'nature', 'cloud.rain.fill', NULL, 'https://zrczvgwexppvgxjxzdjw.supabase.co/storage/v1/object/public/audio-files/rain.mp3'),
  ('Ocean Waves', 'nature', 'waveform', NULL, 'https://zrczvgwexppvgxjxzdjw.supabase.co/storage/v1/object/public/audio-files/ocean.mp3'),
  ('Wind in Trees', 'nature', 'tree.fill', NULL, 'https://zrczvgwexppvgxjxzdjw.supabase.co/storage/v1/object/public/audio-files/wind.mp3'),
  ('Birds Chirping', 'nature', 'bird.fill', NULL, 'https://zrczvgwexppvgxjxzdjw.supabase.co/storage/v1/object/public/audio-files/birds.mp3'),
  ('Distant Thunder', 'nature', 'cloud.bolt.fill', NULL, 'https://zrczvgwexppvgxjxzdjw.supabase.co/storage/v1/object/public/audio-files/thunder.mp3'),
  ('River', 'nature', 'water.waves', NULL, 'https://zrczvgwexppvgxjxzdjw.supabase.co/storage/v1/object/public/audio-files/river.mp3'),
  ('Fireplace', 'indoor', 'flame.fill', NULL, 'https://zrczvgwexppvgxjxzdjw.supabase.co/storage/v1/object/public/audio-files/fireplace.mp3'),
  ('Tibetan Bowls', 'indoor', 'music.note', NULL, 'https://zrczvgwexppvgxjxzdjw.supabase.co/storage/v1/object/public/audio-files/bowls.mp3');
```

### Create `presets` table:

```sql
-- Create presets table
CREATE TABLE IF NOT EXISTS presets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  icon TEXT NOT NULL,
  description TEXT NOT NULL,
  track_configurations JSONB NOT NULL, -- Stores { "Rain": 0.8, "Wind in Trees": 0.3 }
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE presets ENABLE ROW LEVEL SECURITY;

-- Create policy to allow public read access
CREATE POLICY "Allow public read access" ON presets
  FOR SELECT USING (true);

-- Insert sample presets (optional)
INSERT INTO presets (name, icon, description, track_configurations) VALUES
  ('Rainy Day', 'cloud.rain.fill', 'Perfect for cozy focus.', '{"Rain": 0.8, "Wind in Trees": 0.3, "Distant Thunder": 0.2}'::jsonb),
  ('Ocean Breeze', 'waveform', 'Coastal relaxation.', '{"Ocean Waves": 0.9, "Wind in Trees": 0.4}'::jsonb),
  ('Meditation', 'heart.fill', 'Deep peaceful relaxation.', '{"Tibetan Bowls": 0.7, "River": 0.3, "Birds Chirping": 0.2}'::jsonb),
  ('Forest Night', 'tree.fill', 'Deep nature immersion.', '{"Wind in Trees": 0.8, "Birds Chirping": 0.5, "River": 0.4, "Distant Thunder": 0.2}'::jsonb);
```

## 🗂️ Step 3: Set Up Storage

1. Go to **Storage** in Supabase
2. Create a new bucket called `audio-files`
3. Make it **Public** (so the app can access files)
4. Upload your audio files (MP3 format recommended)
5. The files will be accessible at:
   ```
   https://zrczvgwexppvgxjxzdjw.supabase.co/storage/v1/object/public/audio-files/[filename].mp3
   ```

### Storage Bucket Setup:
- **Bucket name**: `audio-files`
- **Public**: ✅ Yes
- **File size limit**: Adjust as needed (default is 50MB)

## 🧪 Step 4: Test the Connection

1. Build and run the app
2. Check the Xcode console for:
   - ✅ Success messages if connected
   - ⚠️ Warning messages if using fallback data
   - ❌ Error messages if something is wrong

## 📝 Notes

- The app will automatically fall back to sample data if Supabase is not configured or if there's an error
- Make sure your audio files are in MP3 format for best compatibility
- The `audio_url` in your database should point to the full Supabase Storage URL
- RLS policies allow public read access - adjust if you need authentication later

## 🔍 Troubleshooting

**App shows sample data instead of Supabase data:**
- Check that your anon key is correctly set in `SupabaseConfig.swift`
- Verify your tables exist and have data
- Check Xcode console for error messages

**Audio files don't play:**
- Verify the storage bucket is public
- Check that `audio_url` in database matches the actual file URL
- Ensure files are uploaded to the `audio-files` bucket

**API errors:**
- Check that RLS policies are set correctly
- Verify table names match exactly: `audio_tracks` and `presets`
- Check that column names match the expected format

