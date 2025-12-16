# Recording Feature - Comprehensive Review & Status

## Overview
This document summarizes the current state of the recording feature and identifies areas for improvement.

## Current Implementation Status

### ✅ Working Components

1. **Recording Flow**
   - `RecordingManager` handles audio recording with proper state management
   - Audio session configuration for recording/playback switching
   - Level metering and duration tracking
   - File management and cleanup

2. **Save Flow**
   - `RecordingMetadataView` provides UI for metadata entry
   - Icon selection, category, title, description, location
   - Automatic token refresh on JWT expiration
   - Notification system for recording saved events

3. **Database Integration**
   - `insert_user_recording` function with SECURITY DEFINER
   - Soft delete via `delete_user_recording` function
   - Update via `update_user_recording` function
   - RLS policies properly configured

4. **UI Components**
   - `UserRecordingsView` with Liquid Glass design
   - `EditRecordingView` for metadata editing
   - Proper navigation and state management

### ⚠️ Known Issues

1. **New Recordings Not Appearing Immediately**
   - **Root Cause**: Supabase read replica lag (eventual consistency)
   - **Current Mitigation**: 
     - 2-second delay after database insert
     - Retry logic with increasing delays (up to 8 attempts)
     - Notification-based refresh system
   - **Status**: Partially resolved - may still experience delays in some cases

2. **Cache Clearing Behavior**
   - **Issue**: Recordings reappear after clearing cache when reopening "My Recordings"
   - **Root Cause**: `onAppear` triggers `loadRecordings()` which fetches from database
   - **Current Fix**: `shouldSkipNextLoad` flag prevents immediate reload
   - **Status**: Should be working, but needs verification

3. **Duration Display**
   - **Issue**: Some recordings show incorrect duration (e.g., "16 hr, 2 mins" for 5-second clips)
   - **Root Cause**: Using `recordedAt` relative time instead of actual `duration`
   - **Status**: Fixed in `EditRecordingView`, but may need verification in other views

## Architecture

### Data Flow

```
RecordingView
  ↓ (user records)
RecordingManager
  ↓ (stops recording)
RecordingMetadataView
  ↓ (user enters metadata)
SupabaseService.uploadRecording()
  ├─→ Upload file to storage
  └─→ Call insert_user_recording() function
      └─→ Post "RecordingSaved" notification
          ├─→ UserRecordingsView (refreshes list)
          └─→ Soundscape3DView (adds to AudioManager)
```

### Key Components

1. **RecordingManager** (`Services/RecordingManager.swift`)
   - Manages audio recording lifecycle
   - Handles audio session configuration
   - Tracks duration and audio levels

2. **SupabaseService** (`Services/SupabaseService.swift`)
   - `uploadRecording()`: Uploads file and creates DB entry
   - `fetchUserRecordings()`: Retrieves user's recordings
   - `updateUserRecording()`: Updates metadata
   - `deleteUserRecording()`: Soft deletes recording

3. **UserRecordingsView** (`UserRecordingsView.swift`)
   - Displays list of user recordings
   - Handles refresh on new recordings
   - Provides cache clearing functionality

4. **EditRecordingView** (`EditRecordingView.swift`)
   - Allows editing metadata
   - Handles update and delete operations

## Recommendations for Improvement

### 1. Database Query Optimization
- Consider adding a `last_updated` timestamp to help with cache invalidation
- Implement optimistic updates for better UX
- Add pagination for users with many recordings

### 2. Error Handling
- Add retry logic for network failures
- Provide user-friendly error messages
- Implement offline queue for failed uploads

### 3. Performance
- Implement lazy loading for large recording lists
- Add image thumbnails for recordings
- Optimize audio file caching

### 4. User Experience
- Add progress indicator during upload
- Show upload status in recording list
- Implement batch operations (delete multiple)

### 5. Testing
- Add unit tests for recording flow
- Test edge cases (network failures, token expiration)
- Verify RLS policies work correctly

## SQL Functions Reference

### `insert_user_recording`
- Parameters: `p_id`, `p_file_path`, `p_duration_seconds`, `p_name`, `p_category`, `p_icon`, `p_description`, `p_location_name`, `p_latitude`, `p_longitude`
- Returns: Recording ID
- Security: SECURITY DEFINER (bypasses RLS)

### `update_user_recording`
- Parameters: `p_id`, `p_name`, `p_category`, `p_description`, `p_icon`
- Returns: Recording ID
- Security: SECURITY DEFINER (bypasses RLS)

### `delete_user_recording`
- Parameters: `p_id`
- Returns: Recording ID
- Security: SECURITY DEFINER (bypasses RLS)
- Behavior: Soft delete (sets `deleted_at`)

## Notification System

### `RecordingSaved` Notification
- Posted after successful database insert
- Contains `recordingId` in `userInfo`
- Listened to by:
  - `UserRecordingsView`: Refreshes list with retry logic
  - `Soundscape3DView`: Adds to AudioManager

## Cache Management

### AudioManager.removeUserRecordings()
- Removes user recordings from `tracks` array
- Stops any active user recordings

### AudioCacheService.clearUserRecordingsCache()
- Removes cached audio files for user recordings
- Preserves other cached ambient sounds

### UserRecordingsView.clearAllCachedRecordings()
- Clears from AudioManager
- Clears cache files
- Clears local state
- Sets `shouldSkipNextLoad` to prevent immediate reload

