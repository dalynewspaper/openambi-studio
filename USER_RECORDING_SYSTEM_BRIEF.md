# 🎤 User Recording System Brief
## OpenAmbi Studio - Complete Recording Functionality Specification

**Date:** December 2024  
**Purpose:** Comprehensive specification for user-generated sound recording, storage, playback, and metadata management

---

## 📋 Executive Summary

This brief details the complete user recording system that allows users to capture, store, loop, and manage their own ambient sound recordings. The system integrates seamlessly with the existing audio architecture while adding rich metadata collection for enhanced user experience.

---

## 🎯 System Overview

### Core Functionality

The user recording system enables users to:
1. **Record** ambient sounds using their device's microphone
2. **Process** recordings with automatic normalization and format conversion
3. **Store** recordings securely in Supabase with user-specific access
4. **Loop** recordings seamlessly using the same AVPlayerLooper system as built-in tracks
5. **Enrich** recordings with automatic and manual metadata (location, images, titles, etc.)
6. **Manage** their personal sound library with full CRUD operations

---

## 🔄 Recording Workflow

### 1. Recording Process

```
User Flow:
┌─────────────────────────────────────────────────────────┐
│ 1. User taps "Record" button                            │
│    ↓                                                     │
│ 2. System checks microphone permission                  │
│    ├─ Not granted → Request permission                  │
│    └─ Granted → Proceed                                 │
│    ↓                                                     │
│ 3. Initialize AVAudioRecorder                           │
│    - Format: M4A (AAC codec)                            │
│    - Sample Rate: 44.1 kHz                              │
│    - Bit Rate: 128 kbps                                 │
│    - Channels: Mono (ambient sounds)                    │
│    ↓                                                     │
│ 4. Start recording to temporary file                    │
│    - Location: App's temp directory                     │
│    - Filename: {timestamp}.m4a                          │
│    ↓                                                     │
│ 5. Display recording UI                                 │
│    - Visual waveform/level meter                        │
│    - Recording timer                                    │
│    - Stop button                                        │
│    ↓                                                     │
│ 6. User taps "Stop"                                      │
│    ↓                                                     │
│ 7. Finalize recording                                   │
│    - Save to temp file                                  │
│    - Calculate duration                                 │
│    - Analyze audio levels                               │
│    ↓                                                     │
│ 8. Show preview & metadata screen                       │
│    - Preview playback                                   │
│    - Auto-generated title                              │
│    - Location data (if available)                      │
│    - Optional image capture                            │
│    - Category selection                                │
│    ↓                                                     │
│ 9. User confirms & saves                                │
│    ↓                                                     │
│ 10. Upload to Supabase Storage                          │
│    - Path: user-recordings/{user_id}/{recording_id}.m4a│
│    ↓                                                     │
│ 11. Create database entry                               │
│    - Insert into user_recordings table                 │
│    - Link metadata                                      │
│    ↓                                                     │
│ 12. Add to AudioManager tracks                         │
│    - Appears in sound library                          │
│    - Available for immediate playback                  │
└─────────────────────────────────────────────────────────┘
```

### 2. Technical Recording Details

#### Audio Format Specifications
- **Container**: M4A (MPEG-4 Audio)
- **Codec**: AAC (Advanced Audio Coding)
- **Sample Rate**: 44.1 kHz (CD quality)
- **Bit Rate**: 128 kbps (optimal balance of quality and file size)
- **Channels**: Mono (sufficient for ambient sounds, reduces file size)
- **File Extension**: `.m4a`

#### Recording Settings (AVAudioRecorder)
```swift
let settings: [String: Any] = [
    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
    AVSampleRateKey: 44100.0,
    AVNumberOfChannelsKey: 1,
    AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
    AVEncoderBitRateKey: 128000
]
```

#### File Size Estimates
- **1 minute**: ~960 KB
- **5 minutes**: ~4.8 MB
- **10 minutes**: ~9.6 MB
- **Maximum recommended**: 30 minutes (~28.8 MB)

---

## 🔁 Looping System

### How Recordings Loop

User recordings use the **exact same looping mechanism** as built-in tracks:

#### Architecture
1. **AVQueuePlayer**: Manages playback queue
2. **AVPlayerLooper**: Handles seamless looping
3. **Streaming Support**: Works with both local files and remote URLs

#### Implementation Details

```swift
// Recording playback uses same system as built-in tracks
let player = AVQueuePlayer(url: recordingURL)
let looper = AVPlayerLooper(player: player, templateItem: playerItem)
audioPlayers[recordingId] = player
playerLooper[recordingId] = looper
```

#### Loop Behavior
- **Seamless**: No gap or silence between loops
- **Automatic**: Starts looping immediately when track is activated
- **Continuous**: Loops indefinitely until user stops or removes track
- **Volume Control**: Respects individual track volume and master volume
- **Spatial Audio**: Supports 3D positioning like built-in tracks

#### Edge Cases Handled
- **Short recordings** (< 5 seconds): Still loop smoothly
- **Long recordings** (> 30 minutes): Loop efficiently without memory issues
- **Network interruptions**: Cached recordings continue looping
- **Background playback**: Loops continue when app is backgrounded

---

## 💾 Storage Architecture

### 1. Supabase Storage Structure

#### Bucket: `user-recordings`
- **Purpose**: Store all user-generated recordings
- **Access**: Private (authenticated users only)
- **Structure**: Organized by user ID for efficient access control

```
user-recordings/
├── {user_id_1}/
│   ├── {recording_id_1}.m4a
│   ├── {recording_id_2}.m4a
│   └── {recording_id_3}.m4a
├── {user_id_2}/
│   ├── {recording_id_4}.m4a
│   └── {recording_id_5}.m4a
└── ...
```

#### File Naming Convention
- **Pattern**: `{recording_id}.m4a`
- **Recording ID**: UUID v4 (e.g., `550e8400-e29b-41d4-a716-446655440000`)
- **Full Path**: `user-recordings/{user_id}/{recording_id}.m4a`
- **Example**: `user-recordings/123e4567-e89b-12d3-a456-426614174000/550e8400-e29b-41d4-a716-446655440000.m4a`

### 2. Database Schema

#### Table: `user_recordings`

```sql
CREATE TABLE user_recordings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Core audio data
    file_path TEXT NOT NULL,  -- Path in storage: "{user_id}/{id}.m4a"
    file_size BIGINT,          -- File size in bytes
    duration DOUBLE PRECISION,  -- Duration in seconds
    
    -- User-provided metadata
    title TEXT NOT NULL,        -- User-entered or auto-generated title
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
    location_address TEXT,      -- Full address if available
    
    -- Visual metadata (optional)
    image_url TEXT,             -- URL to associated image in storage
    image_path TEXT,             -- Path in storage bucket
    
    -- Audio analysis metadata
    average_level DOUBLE PRECISION,  -- Average audio level (0.0-1.0)
    peak_level DOUBLE PRECISION,     -- Peak audio level (0.0-1.0)
    
    -- Playback metadata
    play_count INTEGER DEFAULT 0,
    last_played_at TIMESTAMP WITH TIME ZONE,
    
    -- Soft delete
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- Indexes for performance
CREATE INDEX idx_user_recordings_user_id ON user_recordings(user_id);
CREATE INDEX idx_user_recordings_category ON user_recordings(category);
CREATE INDEX idx_user_recordings_recorded_at ON user_recordings(recorded_at DESC);
CREATE INDEX idx_user_recordings_location ON user_recordings(latitude, longitude) WHERE latitude IS NOT NULL;

-- Row Level Security (RLS)
ALTER TABLE user_recordings ENABLE ROW LEVEL SECURITY;

-- Users can only see their own recordings
CREATE POLICY "Users can view own recordings" ON user_recordings
    FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own recordings
CREATE POLICY "Users can insert own recordings" ON user_recordings
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own recordings
CREATE POLICY "Users can update own recordings" ON user_recordings
    FOR UPDATE USING (auth.uid() = user_id);

-- Users can delete their own recordings (soft delete)
CREATE POLICY "Users can delete own recordings" ON user_recordings
    FOR DELETE USING (auth.uid() = user_id);
```

### 3. Storage Bucket Policies

#### Supabase Storage RLS Policies

```sql
-- Users can upload to their own folder
CREATE POLICY "Users can upload own recordings" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'user-recordings' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );

-- Users can read their own recordings
CREATE POLICY "Users can read own recordings" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'user-recordings' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );

-- Users can update their own recordings
CREATE POLICY "Users can update own recordings" ON storage.objects
    FOR UPDATE USING (
        bucket_id = 'user-recordings' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );

-- Users can delete their own recordings
CREATE POLICY "Users can delete own recordings" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'user-recordings' AND
        (storage.foldername(name))[1] = auth.uid()::text
    );
```

### 4. Local Caching

#### Cache Strategy
- **Location**: App's cache directory
- **Naming**: `{recording_id}.m4a`
- **Purpose**: Offline playback, faster loading
- **Management**: 
  - Cache on first playback
  - Evict oldest when cache exceeds 500 MB
  - Clear cache on app update

---

## 📊 Metadata Collection & Display

### 1. Automatic Metadata

#### A. Location Data

**Collection:**
- **When**: During recording (if permission granted)
- **Method**: CoreLocation framework
- **Frequency**: Single capture at recording start
- **Privacy**: User must grant location permission

**Data Captured:**
```swift
struct LocationMetadata {
    let latitude: Double
    let longitude: Double
    let accuracy: Double          // Horizontal accuracy in meters
    let timestamp: Date
    var locationName: String?     // Reverse geocoded
    var address: String?         // Full address
    var city: String?
    var country: String?
}
```

**Reverse Geocoding:**
- **Service**: CLGeocoder (iOS native)
- **Process**: Convert coordinates → human-readable location
- **Fallback**: Store coordinates if geocoding fails
- **Privacy**: Only geocode if user grants location permission

**Display Options:**
- **Map View**: Show recording location on interactive map
- **Location Badge**: Display city/region name on recording card
- **Location Icon**: Visual indicator on recording item
- **Location Filter**: Filter recordings by location

#### B. Auto-Generated Title

**Title Generation Logic:**
```
Priority Order:
1. User-entered title (if provided)
2. Location-based: "{Location Name} - {Date}"
   Example: "Central Park - Dec 15, 2024"
3. Time-based: "Recording - {Time}"
   Example: "Recording - 3:45 PM"
4. Generic: "My Recording {Number}"
   Example: "My Recording 1"
```

**Smart Title Suggestions:**
- Analyze audio characteristics
- Suggest based on category
- Use time of day context (Morning, Afternoon, Evening, Night)
- Include duration if significant

#### C. Audio Analysis

**Automatic Analysis:**
- **Average Level**: Mean audio amplitude (0.0-1.0)
- **Peak Level**: Maximum audio amplitude (0.0-1.0)
- **Duration**: Total recording length in seconds
- **File Size**: Size in bytes (for storage management)

**Use Cases:**
- **Volume Normalization**: Auto-adjust if too quiet/loud
- **Quality Indicators**: Show audio quality badge
- **Smart Suggestions**: Recommend best recordings

#### D. Timestamp Metadata

**Captured Timestamps:**
- **recorded_at**: When recording was made
- **created_at**: When saved to database
- **updated_at**: Last modification time
- **last_played_at**: Most recent playback time

**Display:**
- Relative time: "2 hours ago", "Yesterday"
- Absolute time: "Dec 15, 2024 at 3:45 PM"
- Duration: "5 minutes 32 seconds"

### 2. User-Provided Metadata

#### A. Title
- **Required**: Yes (with auto-generation fallback)
- **Max Length**: 100 characters
- **Validation**: Trim whitespace, prevent empty strings
- **Editing**: Can be edited after recording

#### B. Category
- **Required**: No (defaults to "My Recordings")
- **Options**: 
  - Nature
  - Indoor
  - Urban
  - Water
  - Wind
  - Fire
  - Custom (user-defined)
- **Purpose**: Organization and filtering

#### C. Description
- **Required**: No
- **Max Length**: 500 characters
- **Purpose**: User notes, context, memories
- **Display**: Shown in detail view, truncated in list

### 3. Visual Metadata

#### A. Image Capture

**Collection Methods:**
1. **Camera Capture**: Take photo during/after recording
2. **Photo Library**: Select existing photo
3. **Auto-Capture**: Automatically capture if camera available

**Storage:**
- **Bucket**: `user-recordings-images` (separate bucket)
- **Path**: `{user_id}/{recording_id}.jpg`
- **Format**: JPEG
- **Compression**: 80% quality (balance size/quality)
- **Max Size**: 1920x1920 pixels (auto-resize if larger)

**Display:**
- **Thumbnail**: 150x150px in list view
- **Full Image**: Full resolution in detail view
- **Map Integration**: Show image on map marker
- **Fallback**: Default icon if no image

**Privacy:**
- **Permission**: Camera/Photo Library access required
- **Optional**: User can skip image capture
- **Storage**: Only stored if user explicitly captures/selects

#### B. Image Analysis (Future Enhancement)
- **Scene Recognition**: Identify environment type
- **Color Extraction**: Extract dominant colors for UI theming
- **Object Detection**: Identify objects in scene

### 4. Metadata Display UI

#### Recording Card (List View)
```
┌─────────────────────────────────────┐
│ [Thumbnail]  Title                  │
│ Image         Location Badge        │
│              Duration • Category    │
│              Last played: 2h ago    │
└─────────────────────────────────────┘
```

#### Recording Detail View
```
┌─────────────────────────────────────┐
│         [Full Image]                │
│                                     │
│  Title: "Central Park - Dec 15"     │
│  Category: Nature                   │
│  Location: 📍 Central Park, NYC     │
│  [Map View Button]                  │
│                                     │
│  Description:                        │
│  "Beautiful morning bird sounds"    │
│                                     │
│  Duration: 5:32                     │
│  Recorded: Dec 15, 2024 at 8:30 AM │
│  File Size: 4.2 MB                  │
│  Play Count: 12                     │
│                                     │
│  [Play] [Edit] [Delete]             │
└─────────────────────────────────────┘
```

#### Map View
- **Display**: All recordings with location data
- **Markers**: Custom pins with recording thumbnails
- **Clustering**: Group nearby recordings
- **Filter**: By category, date range
- **Interaction**: Tap marker → show recording details

---

## 🗺️ Location & Map Features

### 1. Location Services

#### Permission Flow
```
1. User initiates recording
   ↓
2. System checks location permission
   ├─ Not determined → Request permission
   ├─ Denied → Skip location (user can enable in Settings)
   └─ Authorized → Capture location
   ↓
3. Capture single location fix
   ↓
4. Reverse geocode to human-readable name
   ↓
5. Store in database
```

#### Location Accuracy
- **Desired Accuracy**: 100 meters (sufficient for city-level)
- **Timeout**: 10 seconds (don't block recording)
- **Fallback**: Use last known location if current unavailable

### 2. Map Integration

#### Map View Features

**Display Options:**
1. **Single Recording**: Show one recording on map
2. **All Recordings**: Show all user recordings
3. **Category Filter**: Show recordings by category
4. **Date Range**: Show recordings in time period
5. **Heat Map**: Visualize recording density

**Map Controls:**
- **Zoom**: Pinch to zoom
- **Pan**: Drag to move
- **Markers**: Tap to view recording details
- **Clustering**: Auto-cluster nearby recordings
- **Search**: Search by location name

**Marker Design:**
- **Icon**: Custom pin with category color
- **Thumbnail**: Small image preview (if available)
- **Badge**: Play count or date indicator
- **Animation**: Pulse for recent recordings

#### Map Data Source
- **Framework**: MapKit (native iOS)
- **Style**: Standard, Satellite, Hybrid
- **Privacy**: Only shows user's own recordings

### 3. Location-Based Features

#### Smart Organization
- **Group by Location**: Auto-group recordings from same area
- **Location Playlists**: Create playlists by location
- **Location History**: Timeline of recording locations

#### Discovery
- **Nearby Sounds**: Suggest recordings from nearby locations
- **Location Trends**: Show popular recording locations
- **Travel Map**: Visualize recording journey

---

## 🎨 User Experience Enhancements

### 1. Recording Interface

#### Visual Feedback
- **Waveform**: Real-time audio waveform visualization
- **Level Meter**: Visual audio level indicator
- **Timer**: Elapsed recording time
- **Status Indicators**: Recording, Paused, Processing

#### Haptic Feedback
- **Start Recording**: Medium impact
- **Stop Recording**: Light impact
- **Save Success**: Success notification
- **Error**: Error notification

### 2. Preview & Edit Screen

#### Features
- **Playback Controls**: Play, pause, scrub
- **Waveform Display**: Visual representation of recording
- **Metadata Forms**: Title, category, description inputs
- **Location Display**: Show captured location
- **Image Capture**: Camera/photo library buttons
- **Save/Cancel**: Confirm or discard

### 3. Library Integration

#### User Recordings Section
- **Location**: Separate section in sound library
- **Visual Distinction**: Different icon/badge for user recordings
- **Filtering**: Filter by category, date, location
- **Sorting**: By date, name, duration, play count

#### Quick Actions
- **Play**: Immediate playback
- **Edit**: Modify metadata
- **Delete**: Remove recording
- **Share**: Export recording (future)

### 4. Empty States

#### No Recordings
- **Message**: "Start recording your first sound"
- **Action**: Prominent "Record" button
- **Tutorial**: Optional onboarding flow

#### No Location Data
- **Message**: "Enable location to see where you recorded"
- **Action**: Link to Settings
- **Privacy**: Clear explanation of location usage

---

## 🔒 Privacy & Security

### 1. Permissions

#### Required Permissions
- **Microphone**: Required for recording
- **Location**: Optional (enhances experience)
- **Camera**: Optional (for image capture)
- **Photo Library**: Optional (for image selection)

#### Permission Handling
- **Graceful Degradation**: App works without optional permissions
- **Clear Explanations**: Explain why each permission is needed
- **Settings Link**: Easy access to change permissions
- **Respect Denials**: Never prompt repeatedly if denied

### 2. Data Privacy

#### User Data Ownership
- **Full Control**: Users own their recordings
- **Deletion**: Permanent deletion available
- **Export**: Users can download their recordings (future)
- **No Sharing**: Recordings are private by default

#### Location Privacy
- **Opt-In**: Location only captured if permission granted
- **Single Fix**: Only capture location at recording start
- **No Tracking**: No continuous location tracking
- **User Control**: Can delete location data separately

### 3. Security

#### Authentication
- **Required**: User must be authenticated to record
- **Session Management**: Secure token handling
- **Auto-Logout**: Session expires after inactivity

#### Storage Security
- **Encryption**: Files encrypted at rest in Supabase
- **Access Control**: RLS ensures users only access own files
- **Secure Upload**: HTTPS for all uploads
- **File Validation**: Validate file format and size

---

## 📱 Implementation Checklist

### Phase 1: Core Recording
- [ ] Add microphone permission to Info.plist
- [ ] Create RecordingManager service
- [ ] Implement AVAudioRecorder setup
- [ ] Create recording UI with timer
- [ ] Implement stop/save flow
- [ ] Add preview playback

### Phase 2: Storage & Database
- [ ] Create `user-recordings` storage bucket
- [ ] Set up RLS policies for bucket
- [ ] Create `user_recordings` database table
- [ ] Implement upload to Supabase Storage
- [ ] Implement database entry creation
- [ ] Add fetch user recordings method

### Phase 3: Metadata Collection
- [ ] Add location permission to Info.plist
- [ ] Implement location capture
- [ ] Add reverse geocoding
- [ ] Implement auto-title generation
- [ ] Add audio analysis (levels, duration)
- [ ] Create metadata form UI

### Phase 4: Visual Metadata
- [ ] Add camera permission to Info.plist
- [ ] Implement image capture
- [ ] Add photo library selection
- [ ] Create image upload to storage
- [ ] Implement thumbnail generation
- [ ] Add image display in UI

### Phase 5: Map Integration
- [ ] Integrate MapKit framework
- [ ] Create map view component
- [ ] Implement marker placement
- [ ] Add clustering for nearby recordings
- [ ] Create location-based filtering
- [ ] Add map to detail view

### Phase 6: Library Integration
- [ ] Add user recordings section to library
- [ ] Implement filtering and sorting
- [ ] Create recording detail view
- [ ] Add edit/delete functionality
- [ ] Implement empty states
- [ ] Add search functionality

### Phase 7: Polish & Optimization
- [ ] Add haptic feedback
- [ ] Implement loading states
- [ ] Add error handling
- [ ] Optimize file uploads
- [ ] Implement caching strategy
- [ ] Add analytics (optional)

---

## 🚀 Future Enhancements

### Advanced Features
1. **Audio Effects**: Reverb, echo, filters
2. **Multi-Track Recording**: Record multiple sources
3. **Cloud Sync**: Sync across devices
4. **Sharing**: Share recordings with other users
5. **Collaboration**: Collaborative soundscapes
6. **AI Enhancement**: Noise reduction, enhancement
7. **Playlists**: Create playlists of recordings
8. **Tags**: Custom tagging system
9. **Favorites**: Mark favorite recordings
10. **Export**: Download recordings in various formats

### Analytics & Insights
1. **Recording Stats**: Total recordings, total duration
2. **Location Insights**: Most recorded locations
3. **Category Distribution**: Recording categories breakdown
4. **Playback Analytics**: Most played recordings
5. **Time Patterns**: Recording times analysis

---

## 📝 Technical Notes

### File Format Rationale
- **M4A/AAC**: Industry standard, excellent compression
- **44.1 kHz**: CD quality, sufficient for ambient sounds
- **128 kbps**: Good quality-to-size ratio
- **Mono**: Ambient sounds don't require stereo, reduces file size

### Performance Considerations
- **Streaming**: Recordings stream from Supabase (no full download)
- **Caching**: Frequently played recordings cached locally
- **Lazy Loading**: Metadata loaded on demand
- **Background Processing**: Upload/processing in background

### Limitations
- **File Size**: Recommended max 30 minutes (~30 MB)
- **Storage Quota**: Per-user storage limits (configurable)
- **Network**: Requires internet for upload (offline queue future)
- **Battery**: Recording consumes battery (expected)

---

## ✅ Success Metrics

### User Engagement
- Number of recordings per user
- Recording frequency
- Playback rate of user recordings
- Retention of users who record

### Technical Performance
- Upload success rate
- Average upload time
- Playback reliability
- Cache hit rate

### User Satisfaction
- Recording quality satisfaction
- Metadata usage rate
- Location feature adoption
- Image capture rate

---

## 📚 References

### Apple Documentation
- [AVAudioRecorder](https://developer.apple.com/documentation/avfaudio/avaudiorecorder)
- [AVQueuePlayer](https://developer.apple.com/documentation/avfoundation/avqueueplayer)
- [AVPlayerLooper](https://developer.apple.com/documentation/avfoundation/avplayerlooper)
- [CoreLocation](https://developer.apple.com/documentation/corelocation)
- [MapKit](https://developer.apple.com/documentation/mapkit)

### Supabase Documentation
- [Storage](https://supabase.com/docs/guides/storage)
- [Row Level Security](https://supabase.com/docs/guides/auth/row-level-security)
- [Authentication](https://supabase.com/docs/guides/auth)

---

**End of Brief**

