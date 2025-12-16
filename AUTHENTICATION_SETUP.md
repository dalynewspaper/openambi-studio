# 🔐 Authentication Setup Guide

## ✅ Implementation Complete

The authentication system has been implemented with the following components:

1. **AuthManager** - Handles sign up, sign in, sign out, and session management
2. **AuthenticationView** - Beautiful login/signup UI matching app design
3. **App.swift** - Updated to check auth state and show appropriate view
4. **SupabaseService** - Updated to support authenticated requests
5. **Keychain Storage** - Secure token storage using iOS Keychain

---

## 📋 Supabase Database Setup

### Step 1: Enable Authentication in Supabase

1. Go to your Supabase Dashboard: https://app.supabase.com
2. Select your project
3. Go to **Authentication** → **Providers**
4. Ensure **Email** provider is enabled
5. Configure email settings (optional, for password reset emails)

### Step 2: Create User Recordings Table (for Phase 2)

Run this SQL in the Supabase SQL Editor:

```sql
-- Create user_recordings table
CREATE TABLE IF NOT EXISTS user_recordings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('nature', 'indoor', 'custom')),
  file_path TEXT NOT NULL,
  duration DOUBLE PRECISION,
  file_size INT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security (RLS)
ALTER TABLE user_recordings ENABLE ROW LEVEL SECURITY;

-- Users can only view their own recordings
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

### Step 3: Create Storage Bucket for User Recordings

1. Go to **Storage** in Supabase Dashboard
2. Click **New bucket**
3. Name: `user-recordings`
4. **Public bucket**: ❌ NO (private bucket)
5. Click **Create bucket**

#### Set Up Storage Policies

Run this SQL in the Supabase SQL Editor:

```sql
-- Allow users to upload their own files
CREATE POLICY "Users can upload own files" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'user-recordings' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );

-- Allow users to view their own files
CREATE POLICY "Users can view own files" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'user-recordings' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );

-- Allow users to delete their own files
CREATE POLICY "Users can delete own files" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'user-recordings' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );
```

---

## 🧪 Testing the Authentication

### Test Sign Up

1. Run the app
2. You should see the authentication screen
3. Tap "Don't have an account? Sign Up"
4. Enter an email and password
5. Tap "Create Account"
6. You should be signed in and see the main app

### Test Sign In

1. Sign out (if signed in)
2. Enter your email and password
3. Tap "Sign In"
4. You should be signed in

### Test Session Persistence

1. Sign in
2. Close the app completely
3. Reopen the app
4. You should still be signed in (session restored from Keychain)

---

## 🔧 How It Works

### Authentication Flow

1. **App Launch**: `AuthManager` checks for existing session in Keychain
2. **If No Session**: Shows `AuthenticationView`
3. **Sign Up/Sign In**: User enters credentials
4. **AuthManager** makes request to Supabase Auth API
5. **Tokens Saved**: Access token and refresh token stored in Keychain
6. **User Saved**: User info stored in Keychain
7. **App Updates**: `isAuthenticated` becomes `true`, main app shows

### Token Management

- **Access Token**: Used for authenticated API requests
- **Refresh Token**: Used to get new access tokens when expired
- **Storage**: Both stored securely in iOS Keychain
- **Persistence**: Tokens persist across app restarts

### Security Features

- ✅ Passwords never stored locally
- ✅ Tokens stored in secure Keychain
- ✅ Automatic token refresh (when implemented)
- ✅ Row Level Security (RLS) on database
- ✅ Storage bucket policies for user files

---

## 📝 Next Steps (Phase 2: Recording)

Once authentication is working, you can implement recording:

1. **RecordingManager** - Handle audio recording
2. **RecordingView** - Recording UI
3. **Upload to Supabase** - Save recordings to user's account
4. **Fetch User Recordings** - Load user's recordings (already implemented in SupabaseService)

---

## 🐛 Troubleshooting

### "Sign up failed" or "Sign in failed"

- Check Supabase Dashboard → Authentication → Providers
- Ensure Email provider is enabled
- Check network connection
- Verify Supabase URL and API key in `SupabaseConfig.swift`

### Session not persisting

- Check Keychain access permissions
- Verify tokens are being saved (check logs)
- Try signing out and signing in again

### "Invalid response from server"

- Check Supabase project is active
- Verify API URL is correct
- Check network connectivity

---

## 📚 Files Created/Modified

### New Files
- `openambi-studio/Services/AuthManager.swift`
- `openambi-studio/AuthenticationView.swift`

### Modified Files
- `openambi-studio/App.swift` - Added auth state check
- `openambi-studio/Services/SupabaseService.swift` - Added authenticated request support

---

## ✅ Checklist

- [x] AuthManager service created
- [x] AuthenticationView UI created
- [x] App.swift updated with auth state check
- [x] SupabaseService updated for authenticated requests
- [x] Keychain storage implemented
- [x] User model with proper UUID handling
- [ ] Supabase Auth enabled in dashboard
- [ ] User recordings table created
- [ ] Storage bucket created
- [ ] Storage policies configured

---

The authentication system is ready to use! Once you've set up the Supabase database and storage, users can create accounts and sign in.
