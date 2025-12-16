# OpenAmbi Studio - Setup Instructions

## Project Structure

The app has been transformed into an ambient sound mixer similar to the web app. Here's what's been added:

### New Files Created:
1. **Models/AudioTrack.swift** - Data models for audio tracks and presets
2. **Services/AudioManager.swift** - Handles audio playback using AVFoundation
3. **Services/SupabaseService.swift** - Service for fetching audio files from Supabase
4. **AmbientMixerView.swift** - Main mixer interface with volume controls
5. **Config/SupabaseConfig.swift** - Configuration for Supabase credentials

### Modified Files:
- **ContentView.swift** - Updated to use AmbientMixerView instead of RecordView

## Adding Files to Xcode Project

Since these files were created outside Xcode, you need to add them to your project:

1. Open the project in Xcode (already done)
2. Right-click on the `openambi-studio` folder in the Project Navigator
3. Select "Add Files to 'openambi-studio'..."
4. Navigate to and select these folders/files:
   - `Models/` folder (select "Create groups" and "Add to targets: openambi-studio")
   - `Services/` folder (select "Create groups" and "Add to targets: openambi-studio")
   - `Config/` folder (select "Create groups" and "Add to targets: openambi-studio")
   - `AmbientMixerView.swift` (select "Add to targets: openambi-studio")

Alternatively, you can drag and drop the folders/files into Xcode's Project Navigator.

## Supabase Setup

1. **Get your Supabase credentials:**
   - Go to https://app.supabase.com
   - Select your project (or create a new one)
   - Go to Settings > API
   - Copy your "Project URL" and "anon/public" key

2. **Update SupabaseConfig.swift:**
   - Open `openambi-studio/Config/SupabaseConfig.swift`
   - Replace `YOUR_SUPABASE_URL` with your project URL
   - Replace `YOUR_SUPABASE_ANON_KEY` with your anon key

3. **Set up your Supabase database:**
   Create a table called `audio_tracks` with the following structure:
   ```sql
   CREATE TABLE audio_tracks (
     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
     name TEXT NOT NULL,
     category TEXT NOT NULL, -- 'nature' or 'indoor'
     icon TEXT NOT NULL, -- SF Symbol name
     description TEXT,
     audio_url TEXT NOT NULL, -- URL to audio file in Supabase Storage
     created_at TIMESTAMP DEFAULT NOW()
   );
   ```

4. **Upload audio files to Supabase Storage:**
   - Create a storage bucket called `audio-files`
   - Upload your audio files (MP3 format recommended)
   - Make the bucket public or set up proper RLS policies
   - Update the `audio_url` in your database to point to the storage URLs

5. **Update SupabaseService.swift:**
   - Replace the sample data in `fetchAudioTracks()` with actual Supabase queries
   - You can use the Supabase Swift SDK or make direct HTTP requests

## Features Implemented

✅ Master play/pause control
✅ Master volume slider
✅ Individual track volume controls
✅ Track on/off toggle (via volume slider or mute button)
✅ Quick presets (Rainy Day, Ocean Breeze, Meditation, Forest Night)
✅ Nature sounds section
✅ Indoor ambience section
✅ Reset functionality
✅ Audio looping (tracks loop indefinitely)

## Next Steps

1. Add the new files to Xcode project (see above)
2. Configure Supabase credentials
3. Set up your Supabase database and storage
4. Test the app with your audio files
5. (Optional) Add the Supabase Swift SDK for better integration

## Audio File Requirements

- Format: MP3, M4A, or other iOS-supported formats
- Recommended: MP3 for best compatibility
- File size: Keep files reasonable (under 10MB each for streaming)
- Duration: Can be any length (tracks loop automatically)

## Troubleshooting

- **Audio not playing:** Check that audio files are accessible and URLs are correct
- **Build errors:** Make sure all new files are added to the Xcode target
- **Supabase connection:** Verify your URL and API key are correct


