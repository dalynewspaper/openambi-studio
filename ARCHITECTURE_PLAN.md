# 🏗️ OpenAmbi Studio - Architecture Plan for User Accounts & Recording

## 📋 Executive Summary

This document outlines the architectural approach for implementing two major features:
1. **User Account Creation** (Authentication)
2. **User Recording of Soundscapes** (Recording & Upload)

---

## 🎯 Recommendation: **Start with Authentication First**

### Why Authentication First?

1. **Foundation for Everything Else**
   - Recording requires user ownership (who recorded what?)
   - User-specific data needs user IDs
   - Future features (favorites, presets, sync) all need users

2. **Simpler to Implement**
   - Supabase Auth is built-in and well-documented
   - No complex audio recording logic yet
   - Can test authentication flow independently

3. **Enables Better UX**
   - Users can sign up before recording
   - Can save recordings to their account immediately
   - No "lost recordings" if app crashes

4. **Recording Depends on Auth**
   - Need to associate recordings with user IDs
   - Need to upload to user-specific storage paths
   - Need to fetch user's recordings

---

## 🏗️ Architecture Overview

### Current Architecture
```
App.swift
  └── ContentView
       └── Soundscape3DView
            └── AudioManager (playback only)
                 └── SupabaseService (fetch tracks)
```

### Target Architecture (After Both Features)
```
App.swift
  └── AuthManager (NEW - handles auth state)
  └── ContentView
       ├── AuthenticationView (NEW - login/signup)
       └── Soundscape3DView
            ├── AudioManager (playback)
            ├── RecordingManager (NEW - recording)
            └── SupabaseService
                 ├── fetchAudioTracks() (existing)
                 ├── fetchUserRecordings() (NEW)
                 └── uploadRecording() (NEW)
```

---

## 🔐 Phase 1: User Authentication

### 1.1 Architecture Components

#### **AuthManager** (New Service)
- **Purpose**: Centralized authentication state management
- **Responsibilities**:
  - Sign up new users
  - Sign in existing users
  - Sign out
  - Track current user session
  - Handle auth state changes
  - Persist session (keychain)

#### **AuthenticationView** (New UI)
- **Purpose**: Login/signup interface
- **Features**:
  - Email/password sign up
  - Email/password sign in
  - Password reset
  - Social auth (optional: Apple Sign In, Google)

#### **Supabase Auth Integration**
- Use Supabase's built-in authentication
- Store user sessions securely
- Handle token refresh automatically

### 1.2 Database Schema Changes

#### **New Table: `users` (handled by Supabase Auth)**
- Supabase automatically creates this
- Fields: `id`, `email`, `created_at`, etc.

#### **New Table: `user_recordings`**
```sql
CREATE TABLE user_recordings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('nature', 'indoor', 'custom')),
  file_path TEXT NOT NULL,  -- Path in storage: "user-recordings/{user_id}/{recording_id}.m4a"
  duration DOUBLE PRECISION,
  file_size INT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

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

-- Users can delete their own recordings
CREATE POLICY "Users can delete own recordings" ON user_recordings
  FOR DELETE USING (auth.uid() = user_id);
```

### 1.3 Storage Bucket Setup

#### **New Bucket: `user-recordings`**
- **Purpose**: Store user-uploaded recordings
- **Structure**: `user-recordings/{user_id}/{recording_id}.m4a`
- **RLS Policy**: Users can only access their own files

### 1.4 Implementation Steps

1. **Add Supabase Auth SDK**
   - Add dependency to project
   - Configure in `SupabaseConfig.swift`

2. **Create AuthManager Service**
   - `Services/AuthManager.swift`
   - ObservableObject for SwiftUI
   - Methods: `signUp()`, `signIn()`, `signOut()`, `currentUser`

3. **Create AuthenticationView**
   - `AuthenticationView.swift`
   - Email/password forms
   - Error handling
   - Loading states

4. **Update App.swift**
   - Check auth state on launch
   - Show AuthenticationView if not signed in
   - Show main app if signed in

5. **Update SupabaseService**
   - Add authenticated requests
   - Use user session tokens

---

## 🎤 Phase 2: Recording Functionality

### 2.1 Architecture Components

#### **RecordingManager** (New Service)
- **Purpose**: Handle audio recording
- **Responsibilities**:
  - Request microphone permissions
  - Start/stop recording
  - Save recording to temporary file
  - Process audio (normalize, format conversion)
  - Upload to Supabase Storage
  - Create database entry

#### **RecordingView** (New UI)
- **Purpose**: Recording interface
- **Features**:
  - Record button
  - Stop button
  - Recording timer
  - Preview playback
  - Name input
  - Category selection
  - Save/cancel

#### **AudioTrack Model Updates**
- Add `isUserRecording: Bool` flag
- Add `userId: UUID?` for user recordings
- Distinguish between built-in and user recordings

### 2.2 Recording Flow

```
1. User taps "Record" button
   ↓
2. Request microphone permission (if not granted)
   ↓
3. Start AVAudioRecorder
   ↓
4. Show recording UI with timer
   ↓
5. User taps "Stop"
   ↓
6. Save to temporary file (.m4a format)
   ↓
7. Show preview/name input screen
   ↓
8. User enters name, selects category
   ↓
9. Upload to Supabase Storage
   ↓
10. Create entry in user_recordings table
   ↓
11. Add to AudioManager as new track
   ↓
12. User can now play it like any other track
```

### 2.3 Technical Details

#### **Audio Format**
- **Format**: M4A (AAC codec) - same as existing tracks
- **Sample Rate**: 44.1 kHz (standard)
- **Bit Rate**: 128 kbps (good quality, reasonable file size)
- **Channels**: Mono (ambient sounds don't need stereo)

#### **File Naming**
- Pattern: `{user_id}/{recording_id}.m4a`
- Example: `550e8400-e29b-41d4-a716-446655440000/123e4567-e89b-12d3-a456-426614174000.m4a`

#### **Storage Path Structure**
```
user-recordings/
  ├── {user_id_1}/
  │   ├── {recording_id_1}.m4a
  │   └── {recording_id_2}.m4a
  └── {user_id_2}/
      └── {recording_id_3}.m4a
```

### 2.4 Implementation Steps

1. **Add Recording Permissions**
   - Update `Info.plist` with microphone usage description
   - Request permission at runtime

2. **Create RecordingManager**
   - `Services/RecordingManager.swift`
   - Use `AVAudioRecorder`
   - Handle recording lifecycle
   - Process and save audio

3. **Create RecordingView**
   - `RecordingView.swift`
   - Recording UI
   - Preview playback
   - Name/category input

4. **Update SupabaseService**
   - `uploadRecording()` method
   - `fetchUserRecordings()` method
   - Handle authenticated uploads

5. **Update AudioManager**
   - Support local file playback (for user recordings)
   - Handle both remote URLs and local files

6. **Update Soundscape3DView**
   - Add "Record" button/entry point
   - Show user recordings alongside built-in tracks
   - Filter/group user recordings

---

## 🔄 Data Flow Diagrams

### Authentication Flow
```
User opens app
  ↓
AuthManager checks session
  ↓
Session exists? ──No──→ Show AuthenticationView
  │                      ↓
  Yes                    User signs up/signs in
  ↓                      ↓
Show main app           AuthManager creates session
                        ↓
                        Show main app
```

### Recording Flow
```
User taps "Record"
  ↓
RecordingManager requests permission
  ↓
Permission granted? ──No──→ Show permission alert
  │
  Yes
  ↓
Start AVAudioRecorder
  ↓
User records audio
  ↓
User taps "Stop"
  ↓
Save to temp file
  ↓
Show preview/name input
  ↓
User enters name, selects category
  ↓
Upload to Supabase Storage
  ↓
Create database entry
  ↓
Add to AudioManager tracks
  ↓
User can play recording
```

---

## 📁 File Structure

### New Files to Create

```
openambi-studio/
├── Services/
│   ├── AuthManager.swift          (NEW)
│   └── RecordingManager.swift      (NEW)
├── Views/
│   ├── AuthenticationView.swift   (NEW)
│   └── RecordingView.swift        (NEW)
└── Models/
    └── UserRecording.swift        (NEW - optional, or extend AudioTrack)
```

### Files to Modify

```
openambi-studio/
├── App.swift                       (add auth state check)
├── ContentView.swift               (show auth view if needed)
├── Models/AudioTrack.swift         (add user recording fields)
├── Services/
│   ├── SupabaseService.swift      (add auth methods, upload, fetch user recordings)
│   └── AudioManager.swift          (support local files)
└── Soundscape3DView.swift          (add record button, show user recordings)
```

---

## 🔒 Security Considerations

### Authentication
- ✅ Use Supabase Auth (secure, handles tokens)
- ✅ Store tokens in Keychain (not UserDefaults)
- ✅ Automatic token refresh
- ✅ Password hashing handled by Supabase

### Recording Storage
- ✅ Row Level Security (RLS) on database
- ✅ Storage bucket policies (users can only access own files)
- ✅ Authenticated uploads (require valid session)
- ✅ File size limits (prevent abuse)

### Privacy
- ✅ Microphone permission request with clear explanation
- ✅ User can delete their recordings
- ✅ No sharing of recordings without explicit action

---

## 🧪 Testing Strategy

### Authentication Testing
- [ ] Sign up with new email
- [ ] Sign in with existing account
- [ ] Sign out
- [ ] Session persistence (app restart)
- [ ] Token refresh
- [ ] Error handling (invalid credentials, network errors)

### Recording Testing
- [ ] Microphone permission request
- [ ] Start/stop recording
- [ ] Recording quality (audio format)
- [ ] File upload to Supabase
- [ ] Database entry creation
- [ ] Playback of recorded track
- [ ] Looping works correctly
- [ ] Delete recording
- [ ] Multiple recordings per user

---

## 📊 Database Migration Plan

### Step 1: Create Tables
```sql
-- Run in Supabase SQL Editor
CREATE TABLE user_recordings (...);
-- Add RLS policies
```

### Step 2: Create Storage Bucket
- Create `user-recordings` bucket in Supabase Storage
- Set up bucket policies
- Configure CORS if needed

### Step 3: Update Existing Code
- Add auth checks to existing endpoints
- Update AudioTrack model
- Update SupabaseService

---

## 🚀 Implementation Order

### Week 1: Authentication
1. Day 1-2: Set up Supabase Auth, create AuthManager
2. Day 3-4: Create AuthenticationView UI
3. Day 5: Integrate auth into app flow, test

### Week 2: Recording
1. Day 1-2: Create RecordingManager, request permissions
2. Day 3-4: Create RecordingView UI, implement recording
3. Day 5: Upload to Supabase, integrate with AudioManager, test

---

## 💡 Future Enhancements

After both features are complete:
- **Cloud Sync**: Sync recordings across devices
- **Sharing**: Share recordings with other users
- **Editing**: Trim, normalize, add effects
- **Presets**: Save user recording combinations as presets
- **Analytics**: Track which recordings users create/use most

---

## ❓ Questions to Consider

1. **Social Auth**: Do we want Apple Sign In / Google Sign In?
2. **Recording Limits**: Max duration? Max file size? Max recordings per user?
3. **Recording Quality**: What quality settings? (affects file size)
4. **Offline Support**: Can users record offline and upload later?
5. **Recording Preview**: Should users be able to preview before saving?

---

## 📝 Next Steps

1. **Review this plan** - Make sure architecture aligns with your vision
2. **Set up Supabase Auth** - Enable authentication in Supabase dashboard
3. **Start with AuthManager** - Create the authentication service
4. **Build AuthenticationView** - Create the login/signup UI
5. **Test authentication flow** - Ensure it works end-to-end
6. **Then move to recording** - Once auth is solid, add recording

---

## 🎯 Success Criteria

### Authentication
- ✅ Users can create accounts
- ✅ Users can sign in
- ✅ Sessions persist across app restarts
- ✅ Secure token storage

### Recording
- ✅ Users can record audio
- ✅ Recordings loop seamlessly like built-in tracks
- ✅ Recordings are saved to user's account
- ✅ Users can play their recordings
- ✅ Users can delete their recordings

---

This architecture provides a solid foundation for both features while maintaining clean separation of concerns and scalability for future enhancements.
