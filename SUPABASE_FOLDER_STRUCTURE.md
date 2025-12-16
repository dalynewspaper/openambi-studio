# Supabase Folder Structure Guide

## 📁 Storage Bucket Organization

Your `ambient-sounds` bucket is organized into folders:

```
ambient-sounds/
├── nature/
│   ├── birds.m4a
│   ├── ocean.m4a
│   ├── rain.m4a
│   ├── river.m4a
│   ├── thunder.m4a
│   └── wind.m4a
└── indoor/
    ├── fireplace.m4a
    └── tibetan-bowl.m4a
```

## 📊 Database Table Structure

Your `ambient_sounds` table should use `file_path` that includes the folder structure:

### Example Database Entries:

```sql
-- Nature sounds
INSERT INTO ambient_sounds (name, category, file_path) VALUES
  ('Birds Chirping', 'nature', 'nature/birds.m4a'),
  ('Ocean Waves', 'nature', 'nature/ocean.m4a'),
  ('Rain', 'nature', 'nature/rain.m4a'),
  ('River', 'nature', 'nature/river.m4a'),
  ('Distant Thunder', 'nature', 'nature/thunder.m4a'),
  ('Wind in Trees', 'nature', 'nature/wind.m4a');

-- Indoor sounds
INSERT INTO ambient_sounds (name, category, file_path) VALUES
  ('Fireplace', 'indoor', 'indoor/fireplace.m4a'),
  ('Tibetan Bowls', 'indoor', 'indoor/tibetan-bowl.m4a');
```

## 🔧 How It Works

1. **File Path Format**: The `file_path` field should include the folder structure:
   - ✅ `"nature/rain.m4a"` → Streams from `ambient-sounds/nature/rain.m4a`
   - ✅ `"indoor/fireplace.m4a"` → Streams from `ambient-sounds/indoor/fireplace.m4a`
   - ❌ `"rain.m4a"` → Would look in root folder (won't work with your structure)

2. **URL Construction**: The app automatically constructs:
   ```
   https://zrczvgwexppvgxjxzdjw.supabase.co/storage/v1/object/public/ambient-sounds/{file_path}
   ```

3. **Category Matching**: The `category` field should match the folder name:
   - `category: "nature"` → files in `nature/` folder
   - `category: "indoor"` → files in `indoor/` folder

## ✅ Updated Code Features

- ✅ Handles folder paths in `file_path` (e.g., "nature/rain.mp4")
- ✅ URL encodes paths to handle special characters
- ✅ Supports both MP3 and MP4 files
- ✅ Maintains folder structure in storage URLs

## 🧪 Testing

1. **Verify Database Entries**:
   ```sql
   SELECT name, category, file_path FROM ambient_sounds;
   ```
   Should show entries like:
   - `name: "Rain"`, `category: "nature"`, `file_path: "nature/rain.m4a"`

2. **Check Console Logs**:
   - Look for: `✅ Loaded track: Rain from https://.../nature/rain.m4a`

3. **Test Playback**:
   - Both nature and indoor tracks should load and play
   - Audio should stream from the correct folder paths

## 📝 Quick Setup SQL

If you need to set up the table with sample data:

```sql
-- Create table if it doesn't exist
CREATE TABLE IF NOT EXISTS ambient_sounds (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  file_path TEXT NOT NULL,
  file_size INT,
  duration DOUBLE PRECISION,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE ambient_sounds ENABLE ROW LEVEL SECURITY;

-- Allow public read access
CREATE POLICY "Allow public read access" ON ambient_sounds
  FOR SELECT USING (true);

-- Insert nature sounds
INSERT INTO ambient_sounds (name, category, file_path) VALUES
  ('Birds Chirping', 'nature', 'nature/birds.m4a'),
  ('Ocean Waves', 'nature', 'nature/ocean.m4a'),
  ('Rain', 'nature', 'nature/rain.m4a'),
  ('River', 'nature', 'nature/river.m4a'),
  ('Distant Thunder', 'nature', 'nature/thunder.m4a'),
  ('Wind in Trees', 'nature', 'nature/wind.m4a')
ON CONFLICT DO NOTHING;

-- Insert indoor sounds
INSERT INTO ambient_sounds (name, category, file_path) VALUES
  ('Fireplace', 'indoor', 'indoor/fireplace.m4a'),
  ('Tibetan Bowls', 'indoor', 'indoor/tibetan-bowl.m4a')
ON CONFLICT DO NOTHING;
```

## 🔍 Troubleshooting

### Files not loading:
- ✅ Check that `file_path` includes folder name (e.g., "nature/rain.m4a", not just "rain.m4a")
- ✅ Verify folder names match exactly: `nature/` and `indoor/` (case-sensitive)
- ✅ Ensure file names match exactly (e.g., "tibetan-bowl.m4a" with lowercase and hyphen)

### Audio not playing:
- ✅ Verify the full URL is correct in console logs
- ✅ Check that files exist in the correct folders in Supabase Storage
- ✅ Ensure bucket is public
- ✅ Test the URL directly in a browser to confirm accessibility

### Category mismatch:
- ✅ Ensure `category` field matches folder name: "nature" or "indoor"
- ✅ The app uses category for filtering and icon selection

---

**Note**: The app now properly handles the folder structure, so your `file_path` values should include the folder name (e.g., "nature/rain.m4a") to match your storage organization. All files are in .m4a format.

