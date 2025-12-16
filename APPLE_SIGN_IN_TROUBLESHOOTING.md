# 🔧 Apple Sign In Troubleshooting Guide

## Current Errors

You're seeing:
- `AKAuthenticationError Code=-7026` - App not configured for Sign in with Apple
- `ASAuthorizationController credential request failed Code=1000` - Generic authorization error

---

## ✅ Required Setup Checklist

### 1. Enable "Sign in with Apple" Capability in Xcode

**This is critical!** The app must have this capability enabled:

1. Open your project in Xcode
2. Select the **openambi-studio** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability** button (top left)
5. Search for and add **"Sign in with Apple"**
6. Verify it appears in the capabilities list

**If this capability is missing, Apple Sign In will fail with error -7026.**

### 2. Verify Bundle Identifier

Your bundle identifier must be: `co.fourthquarterstudio.openambi`

1. In Xcode, select your target
2. Go to **General** tab
3. Check **Bundle Identifier**: Should be `co.fourthquarterstudio.openambi`
4. This must match:
   - Info.plist URL scheme
   - Apple Developer App ID (if you create one)
   - Supabase redirect URLs

### 3. Test on Physical Device

**Sign in with Apple does NOT work in the iOS Simulator.**

You must test on a **physical iPhone/iPad**:
- Connect your device via USB
- Select your device in Xcode's device menu
- Build and run (⌘R)

### 4. Verify Apple ID is Signed In

On your physical device:
1. Go to **Settings** → **[Your Name]** (top of Settings)
2. Make sure you're signed in to iCloud with an Apple ID
3. If not signed in, sign in first

### 5. Configure in Supabase (Still Required)

Even with the app configured, you still need to set up OAuth in Supabase:
- See `OAUTH_SETUP_GUIDE.md` for instructions
- This is required for the backend authentication

---

## 🐛 Error Code Meanings

### AKAuthenticationError Code=-7026
**Meaning**: App is not properly configured for Sign in with Apple

**Solutions**:
1. ✅ Add "Sign in with Apple" capability in Xcode
2. ✅ Verify bundle identifier matches
3. ✅ Test on physical device (not simulator)
4. ✅ Make sure you're signed in to iCloud on device

### ASAuthorizationError Code=1000
**Meaning**: Unknown/Generic authorization error

**Common Causes**:
- Missing capability in Xcode
- Testing in simulator (doesn't work)
- Not signed in to iCloud
- App not properly signed/provisioned

---

## 🔍 Quick Diagnostic Steps

1. **Check Capability**:
   - Xcode → Target → Signing & Capabilities
   - Look for "Sign in with Apple" in the list
   - If missing, add it!

2. **Check Device**:
   - Are you testing in simulator? → Switch to physical device
   - Is device signed in to iCloud? → Check Settings

3. **Check Bundle ID**:
   - Xcode → Target → General → Bundle Identifier
   - Should be: `co.fourthquarterstudio.openambi`

4. **Check Signing**:
   - Xcode → Target → Signing & Capabilities
   - "Automatically manage signing" should be checked
   - Team should be selected

---

## 📝 Step-by-Step Fix

### Step 1: Add Capability (Most Important!)

1. In Xcode, click on your project (blue icon at top)
2. Select **openambi-studio** target
3. Click **Signing & Capabilities** tab
4. Click **+ Capability** (top left, next to "All")
5. Type "Sign in" and double-click **"Sign in with Apple"**
6. It should appear in your capabilities list

### Step 2: Clean Build

1. Product → Clean Build Folder (⇧⌘K)
2. Product → Build (⌘B)
3. Fix any errors that appear

### Step 3: Test on Physical Device

1. Connect iPhone via USB
2. Select your device in Xcode's device menu
3. Product → Run (⌘R)
4. Try Sign in with Apple

---

## ⚠️ Important Notes

- **Simulator**: Sign in with Apple will NOT work in iOS Simulator
- **Capability**: Must be added in Xcode - it's not automatic
- **Bundle ID**: Must be consistent across all configurations
- **iCloud**: Device must be signed in to iCloud

---

## ✅ Success Indicators

When properly configured, you should:
- See the Apple Sign In button without errors
- Be able to tap it and see the Apple authentication sheet
- Complete the authentication flow
- Get redirected back to the app

---

## 🆘 Still Not Working?

If you've completed all steps and it still fails:

1. **Check Xcode Console** for more specific error messages
2. **Verify Apple Developer Account** - Make sure your team is properly configured
3. **Check Device Logs** - Settings → Privacy & Security → Analytics & Improvements → Analytics Data
4. **Try a different Apple ID** - Sometimes specific accounts have issues

The most common issue is **missing the "Sign in with Apple" capability** in Xcode. Make sure it's added! 🔑
