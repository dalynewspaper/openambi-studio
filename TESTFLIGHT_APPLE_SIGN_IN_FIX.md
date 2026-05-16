# TestFlight: Sign in with Apple Fix Guide

## Problem
Sign in with Apple works in development builds but fails in TestFlight builds.

## Root Cause
For TestFlight builds, the App ID must have "Sign in with Apple" enabled in the **Apple Developer Portal**, not just in Xcode. Xcode capabilities are not enough for TestFlight/App Store builds.

**⚠️ CRITICAL: Team Mismatch Issue**
If you see multiple teams in Xcode (e.g., "Brian Daly" and "Brian Daly (Personal Team)"), you MUST use the **paid Developer Program team**, NOT the Personal Team. The Personal Team cannot enable Sign in with Apple or create TestFlight builds.

## ✅ Required Steps

### Step 0: Verify You're Using the Correct Team (CRITICAL!)

**This is the most common cause of TestFlight issues!**

1. In Xcode, go to **Signing & Capabilities** tab
2. Check the **Team** dropdown
3. **You MUST select the paid Developer Program team**, NOT "Personal Team"
   - ✅ **Correct**: "Brian Daly" (or your company name) - This is your paid Developer Program
   - ❌ **Wrong**: "Brian Daly (Personal Team)" - This is the free personal team with limitations

**How to identify the correct team:**
- Paid Developer Program team: Shows your name/company, can create App Store builds
- Personal Team: Has "(Personal Team)" suffix, CANNOT create TestFlight/App Store builds

**If you only see Personal Team:**
- You need to enroll in the Apple Developer Program ($99/year)
- Go to: https://developer.apple.com/programs/
- After enrolling, add your account in Xcode → Settings → Accounts

**Verify team in Developer Portal:**
1. Go to [Apple Developer Portal](https://developer.apple.com/account/)
2. Check the top right - it should show your paid Developer Program membership
3. If it shows "Free" or "Personal Team", you need to enroll

### Step 1: Enable Sign in with Apple in Apple Developer Portal

**⚠️ IMPORTANT: Make sure you're signed in with your PAID Developer Program account, not a Personal Team account!**

1. Go to [Apple Developer Portal](https://developer.apple.com/account/)
2. Sign in with your Apple Developer account
3. Navigate to **Certificates, Identifiers & Profiles**
4. Click **Identifiers** in the left sidebar
5. Find and click on your **App ID** (e.g., `co.fourthquarterstudio.openambi`)
   - If you don't see it, you may need to create it first
6. Scroll down to **Capabilities**
7. Find **Sign in with Apple** in the list
8. **Check the box** to enable it
9. Click **Save** (top right)
10. Wait for the changes to propagate (usually a few minutes)

### Step 2: Verify Xcode Configuration

1. Open your project in Xcode
2. Select your app target
3. Go to **Signing & Capabilities** tab
4. **CRITICAL: Select the correct Team**
   - Click the **Team** dropdown
   - Select your **paid Developer Program team** (NOT Personal Team)
   - The team name should NOT have "(Personal Team)" suffix
5. Verify **Sign in with Apple** capability is listed
   - If not, click **+ Capability** and add it
   - If you see an error about the capability, it's likely a team mismatch issue
6. Make sure **Automatically manage signing** is checked
7. Check the **Provisioning Profile** - it should say "Xcode Managed Profile" for your Developer Program team

**If you see errors about capabilities:**
- The App ID might be registered under the wrong team
- Delete the capability, switch to correct team, then re-add it
- Or create a new App ID under the correct team in Developer Portal

### Step 3: Verify Bundle Identifier

1. In Xcode, go to **General** tab
2. Check **Bundle Identifier**: Should match your App ID in Developer Portal
3. Example: `co.fourthquarterstudio.openambi`

### Step 4: Clean and Rebuild

1. In Xcode: **Product** → **Clean Build Folder** (⇧⌘K)
2. **Product** → **Build** (⌘B)
3. Fix any errors

### Step 5: Create New Archive

1. Select **Any iOS Device** in device selector
2. **Product** → **Archive**
3. Wait for archive to complete
4. **Distribute App** → **App Store Connect** → **Upload**

### Step 6: Wait for Processing

1. Go to App Store Connect → **My Apps** → Your App
2. Click **TestFlight** tab
3. Wait for Apple to process the build (10-60 minutes)
4. Once processed, test Sign in with Apple

## 🔍 Team Verification Checklist

Before proceeding, verify:

- [ ] You have a **paid Apple Developer Program** membership ($99/year)
- [ ] In Xcode, you're signed in with the **paid Developer Program account**
- [ ] In Xcode → Signing & Capabilities, the **Team** selected is NOT "Personal Team"
- [ ] In Developer Portal, you're signed in with the **paid Developer Program account**
- [ ] The App ID in Developer Portal shows your **paid Developer Program team**, not Personal Team
- [ ] All capabilities (Sign in with Apple, Background Modes) are enabled under the **correct team's App ID**

**How to check which team owns your App ID:**
1. Go to Developer Portal → Identifiers → Your App ID
2. Look at the top of the page - it should show your paid Developer Program team name
3. If it shows "Personal Team" or a different team, that's the problem!

## 🔍 Diagnostic Information

The app now includes enhanced logging. When Sign in with Apple fails, check the Xcode console for:

- `❌ Apple Sign In failed:` - Shows the specific error
- `ASAuthorizationError code:` - The error code
- `NSError domain:` and `code:` - Additional error details

### Common Error Codes:

- **Code -7026**: App ID not configured in Developer Portal
- **Code 1000**: Generic error, usually means capability missing
- **Code 1001**: User canceled (not an error)

## ⚠️ Important Notes

1. **App ID Configuration is Required**: Just adding the capability in Xcode is NOT enough for TestFlight. You MUST enable it in the Developer Portal.

2. **Propagation Time**: Changes in Developer Portal can take 5-15 minutes to propagate. Wait before testing.

3. **New Build Required**: After enabling in Developer Portal, you need to create a NEW archive and upload it to TestFlight.

4. **Simulator Limitation**: Sign in with Apple doesn't work in iOS Simulator. Always test on a physical device or TestFlight.

5. **Bundle ID Must Match**: The Bundle Identifier in Xcode must exactly match the App ID in Developer Portal.

## ✅ Verification Checklist

- [ ] App ID created in Apple Developer Portal
- [ ] Sign in with Apple enabled for App ID in Developer Portal
- [ ] Sign in with Apple capability added in Xcode
- [ ] Bundle Identifier matches App ID
- [ ] Team selected in Xcode signing
- [ ] New archive created after enabling in Developer Portal
- [ ] Build uploaded to TestFlight
- [ ] Build processed by Apple
- [ ] Tested on physical device via TestFlight

## 🆘 Still Not Working?

If you've completed all steps and it still fails:

1. **Verify Team Match**: 
   - Check Xcode Team matches Developer Portal team
   - Make sure App ID was created under the PAID Developer Program team
   - Personal Team App IDs cannot be used for TestFlight

2. **Check Console Logs**: Look for specific error codes in Xcode console
   - Error -7026: Usually means App ID not configured or wrong team
   - Error 1000: Generic error, often team/capability mismatch

3. **Verify App ID Ownership**:
   - Go to Developer Portal → Identifiers → Your App ID
   - Check which team owns it (should be your paid Developer Program team)
   - If it's under Personal Team, you need to create a new App ID under the correct team

4. **Recreate App ID** (if team mismatch):
   - Create new App ID in Developer Portal under PAID Developer Program team
   - Update Bundle Identifier in Xcode to match
   - Enable all capabilities (Sign in with Apple, Background Modes)
   - Create new archive and upload

5. **Wait Longer**: Sometimes changes take 30+ minutes to propagate

6. **Check Supabase**: Ensure Apple OAuth is configured in Supabase Dashboard

7. **Verify Provisioning Profile**:
   - In Xcode, check the Provisioning Profile name
   - It should include your Developer Program team name
   - If it says "Personal Team" anywhere, that's the problem

## 📝 Quick Reference

**Developer Portal**: https://developer.apple.com/account/resources/identifiers/list

**Path**: Certificates, Identifiers & Profiles → Identifiers → [Your App ID] → Capabilities → Sign in with Apple

**Xcode Path**: Target → Signing & Capabilities → + Capability → Sign in with Apple

