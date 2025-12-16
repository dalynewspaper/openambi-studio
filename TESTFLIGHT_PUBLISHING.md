# Publishing to TestFlight Guide

This guide will walk you through publishing OpenAmbi Studio to TestFlight for beta testing.

## Prerequisites

1. **Apple Developer Account** (paid membership - $99/year)
   - Sign up at: https://developer.apple.com/programs/
   - You'll need to enroll in the Apple Developer Program

2. **App Store Connect Access**
   - Access at: https://appstoreconnect.apple.com
   - Use your Apple ID that's enrolled in the Developer Program

## Step 1: Configure Your Xcode Project

### 1.1 Set Bundle Identifier

1. Open your project in Xcode
2. Select the project in the navigator (top item)
3. Select the **openambi-studio** target
4. Go to the **General** tab
5. Under **Identity**, set:
   - **Bundle Identifier**: `com.yourcompany.openambistudio` (replace `yourcompany` with your actual identifier)
   - **Version**: `1.0` (or your version number)
   - **Build**: `1` (increment this for each build)

### 1.2 Configure Signing & Capabilities

1. Still in the **General** tab, scroll to **Signing & Capabilities**
2. Check **Automatically manage signing**
3. Select your **Team** (your Apple Developer account)
4. Xcode will automatically create/select a provisioning profile

### 1.3 Set Deployment Target

1. In the **General** tab, under **Deployment Info**
2. Set **iOS Deployment Target** to `17.0` or your minimum supported iOS version
3. Ensure it matches your code requirements

### 1.4 Configure App Icons and Launch Screen

1. In the **General** tab, under **App Icons and Launch Screen**
2. Add your app icon (1024x1024px required for App Store)
3. Configure your launch screen

## Step 2: Create App in App Store Connect

1. Go to https://appstoreconnect.apple.com
2. Click **My Apps** → **+** → **New App**
3. Fill in:
   - **Platform**: iOS
   - **Name**: OpenAmbi Studio (or your app name)
   - **Primary Language**: English (or your language)
   - **Bundle ID**: Select the bundle ID you set in Xcode
   - **SKU**: A unique identifier (e.g., `openambi-studio-001`)
   - **User Access**: Full Access (or Limited Access if needed)
4. Click **Create**

## Step 3: Archive Your App

### 3.1 Clean Build Folder

1. In Xcode, go to **Product** → **Clean Build Folder** (Shift + Cmd + K)

### 3.2 Select Generic iOS Device

1. In the device selector (top toolbar), select **Any iOS Device** or **Generic iOS Device**
   - Do NOT select a simulator

### 3.3 Archive

1. Go to **Product** → **Archive**
2. Wait for the archive to complete (this may take a few minutes)
3. The **Organizer** window will open automatically

## Step 4: Upload to App Store Connect

### 4.1 Validate Archive (Optional but Recommended)

1. In the **Organizer** window, select your archive
2. Click **Validate App**
3. Follow the prompts:
   - Select your team
   - Click **Validate**
4. Fix any issues that appear

### 4.2 Distribute App

1. In the **Organizer** window, select your archive
2. Click **Distribute App**
3. Select **App Store Connect**
4. Click **Next**
5. Select **Upload**
6. Click **Next**
7. Select your distribution options:
   - ✅ **Upload your app's symbols** (recommended for crash reports)
   - ✅ **Manage Version and Build Number** (if you want Xcode to manage it)
8. Click **Next**
9. Select your signing options:
   - **Automatically manage signing** (recommended)
10. Click **Next**
11. Review the summary and click **Upload**
12. Wait for upload to complete (this may take 10-30 minutes depending on your connection)

## Step 5: Set Up TestFlight

### 5.1 Wait for Processing

1. Go to App Store Connect → **My Apps** → **OpenAmbi Studio**
2. Click on **TestFlight** tab
3. Wait for Apple to process your build (usually 10-60 minutes)
   - You'll see a yellow "Processing" status
   - You'll receive an email when processing is complete

### 5.2 Add Test Information

1. Once processing is complete, select your build
2. Click **Add to TestFlight**
3. Fill in **What to Test**:
   - Provide instructions for testers
   - Describe what features to test
   - Note any known issues

### 5.3 Add Internal Testers (Optional)

1. Go to **TestFlight** → **Internal Testing**
2. Click **+** to create a group
3. Name it (e.g., "Development Team")
4. Add testers:
   - Go to **Users and Access** → **Users**
   - Add team members (up to 100 internal testers)
   - They must accept the invitation

### 5.4 Add External Testers (Recommended)

1. Go to **TestFlight** → **External Testing**
2. Click **+** to create a group
3. Name it (e.g., "Beta Testers")
4. Add your build to the group
5. Click **Next**
6. Fill in **Test Information**:
   - What to test
   - Feedback email
   - Privacy policy URL (if required)
7. Click **Next**
8. Review and submit for Beta App Review
   - First external test requires Apple review (usually 24-48 hours)
   - Subsequent builds are usually faster

### 5.5 Invite Testers

1. Once your build is approved (for external testing)
2. Go to your test group
3. Click **Add Testers** or share the public link
4. Testers will receive an email invitation
5. They need to:
   - Install the TestFlight app from the App Store
   - Accept the invitation
   - Install your app from TestFlight

## Step 6: Update Your App

For subsequent builds:

1. Increment the **Build** number in Xcode (General tab)
2. Archive again (Product → Archive)
3. Upload the new build
4. Once processed, add it to your TestFlight groups
5. Testers will be notified of the update

## Troubleshooting

### Common Issues

1. **"No accounts with App Store Connect access"**
   - Ensure you're signed in with an Apple ID enrolled in the Developer Program
   - Check **Xcode** → **Preferences** → **Accounts**

2. **"Bundle identifier is already in use"**
   - The bundle ID must be unique
   - Change it in Xcode or use a different one

3. **"Invalid Bundle"**
   - Check that your deployment target is correct
   - Ensure all required app icons are present
   - Verify signing is configured correctly

4. **"Missing Compliance"**
   - In App Store Connect, go to **App Privacy**
   - Answer the privacy questions
   - This is required for TestFlight

5. **Upload Fails**
   - Check your internet connection
   - Try using **Transporter** app (from Mac App Store) as an alternative
   - Check Xcode → **Window** → **Organizer** for error details

### Required Information in App Store Connect

Before you can submit for external testing, you'll need:

- ✅ App name and description
- ✅ Privacy policy URL (if your app collects data)
- ✅ App icon (1024x1024px)
- ✅ Screenshots (at least one set for iPhone)
- ✅ App category
- ✅ Age rating

## Quick Checklist

- [ ] Apple Developer Account enrolled
- [ ] Bundle identifier set in Xcode
- [ ] Signing configured with your team
- [ ] App created in App Store Connect
- [ ] App archived successfully
- [ ] Build uploaded to App Store Connect
- [ ] Build processed by Apple
- [ ] Test information added
- [ ] Testers invited
- [ ] Privacy compliance completed (if needed)

## Additional Resources

- [App Store Connect Help](https://help.apple.com/app-store-connect/)
- [TestFlight Documentation](https://developer.apple.com/testflight/)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

## Notes for OpenAmbi Studio

Since your app uses:
- **Background Audio**: Ensure you've configured the background modes in Xcode
  - Go to **Signing & Capabilities** → **+ Capability** → **Background Modes**
  - Check **Audio, AirPlay, and Picture in Picture**
- **Supabase**: Ensure your API keys are properly configured for production
- **Network Access**: Add network permissions if needed in Info.plist

Good luck with your TestFlight release! 🚀

