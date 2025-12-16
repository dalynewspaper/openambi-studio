# TestFlight Publishing - Step-by-Step Guide

Follow these steps in order while Xcode is open.

## ✅ Step 1: Check Your Apple Developer Account

**Before we start:**
- [ ] Do you have an Apple Developer Account? ($99/year)
  - If NO: Go to https://developer.apple.com/programs/ and enroll
  - If YES: Continue to Step 2

**Verify your account in Xcode:**
1. In Xcode, go to **Xcode** → **Settings** (or **Preferences** on older versions)
2. Click the **Accounts** tab
3. Click the **+** button at bottom left
4. Sign in with your Apple ID that's enrolled in the Developer Program
5. Your team should appear in the list

---

## ✅ Step 2: Configure Bundle Identifier

**Current bundle ID:** `com.example.openambistudio` (needs to be changed)

1. In Xcode's left sidebar (Project Navigator), click the **blue project icon** at the very top (labeled "openambi-studio")
2. In the main area, you'll see project settings
3. Under **TARGETS**, select **openambi-studio** (the app target, not the project)
4. Click the **General** tab at the top
5. Find **Identity** section
6. Change **Bundle Identifier** from `com.example.openambistudio` to:
   - `com.yourname.openambistudio` (replace "yourname" with your name/company)
   - OR: `com.yourcompany.openambistudio`
   - **Important:** This must be unique and match what you'll create in App Store Connect

**Example:** `com.briandaly.openambistudio`

---

## ✅ Step 3: Set Version and Build Numbers

**Still in the General tab:**

1. Find **Identity** section (same area as Bundle Identifier)
2. Set **Version** to: `1.0` (or your version number)
3. Set **Build** to: `1` (increment this for each new build you upload)

**Note:** You'll increment the Build number each time you upload a new version to TestFlight.

---

## ✅ Step 4: Configure Signing & Capabilities

**Still in the General tab, scroll down:**

1. Find **Signing & Capabilities** section
2. Check the box: **☑ Automatically manage signing**
3. Under **Team**, click the dropdown
4. Select your **Apple Developer team** (should show your name/company)
5. If you see an error, make sure you're signed in (Step 1)

**If you see signing errors:**
- Xcode will automatically create certificates and provisioning profiles
- Wait a moment for it to process
- If errors persist, click "Try Again" or check your Apple Developer account status

---

## ✅ Step 5: Configure Background Audio Capability

**Your app uses background audio, so we need to enable it:**

1. Still in **Signing & Capabilities** tab
2. Click **+ Capability** button (top left of the capabilities list)
3. Search for "Background Modes"
4. Double-click **Background Modes** to add it
5. In the Background Modes section that appears, check:
   - ☑ **Audio, AirPlay, and Picture in Picture**

This allows your app to play audio in the background.

---

## ✅ Step 6: Set Deployment Target

**Still in the General tab:**

1. Find **Deployment Info** section
2. Set **iOS** to: `17.0` (or your minimum supported iOS version)
3. Make sure it matches what your code requires

---

## ✅ Step 7: Create App in App Store Connect

**Now we'll create the app listing:**

1. Open a web browser
2. Go to: https://appstoreconnect.apple.com
3. Sign in with your Apple ID (same one used in Xcode)
4. Click **My Apps** in the top navigation
5. Click the **+** button (top left)
6. Select **New App**

**Fill in the form:**
- **Platform:** Select **iOS**
- **Name:** `OpenAmbi Studio` (or your preferred name)
- **Primary Language:** Select your language (e.g., English)
- **Bundle ID:** Select the bundle ID you just set in Xcode
  - If it doesn't appear, you may need to create it first:
    - Go to **Certificates, Identifiers & Profiles** → **Identifiers** → **+** → **App IDs**
    - Register your bundle ID
- **SKU:** Enter a unique identifier (e.g., `openambi-studio-001`)
  - This is just for your records, can be anything unique
- **User Access:** Select **Full Access** (unless you need limited access)

7. Click **Create**

**You'll see:** "Your app has been created. Add version information and prepare it for submission."

---

## ✅ Step 8: Clean and Prepare for Archive

**Back in Xcode:**

1. Go to **Product** → **Clean Build Folder** (or press `Shift + Cmd + K`)
2. Wait for it to complete (you'll see "Clean Succeeded" in the status bar)

**Important:** Make sure you're NOT building for simulator.

---

## ✅ Step 9: Select Generic iOS Device

**Before archiving, you must select a real device (not simulator):**

1. Look at the top toolbar in Xcode
2. Find the device selector (next to the Run/Stop buttons)
3. Click the dropdown
4. Select **Any iOS Device** (or **Generic iOS Device**)
   - **DO NOT** select a simulator (like "iPhone 16 Pro Simulator")
   - If you only see simulators, you may need to connect a physical device or just select "Any iOS Device"

---

## ✅ Step 10: Archive Your App

**Now we'll create an archive for distribution:**

1. In Xcode menu bar, go to **Product** → **Archive**
2. Wait for the build to complete (this may take 2-5 minutes)
   - You'll see progress in the status bar at the top
   - The build will compile all your code
3. When complete, the **Organizer** window will open automatically
   - If it doesn't open, go to **Window** → **Organizer**

**You should see:**
- Your archive listed with today's date
- The version and build numbers you set
- Status showing it's ready

---

## ✅ Step 11: Validate Your Archive (Recommended)

**This checks for common issues before uploading:**

1. In the **Organizer** window, select your archive
2. Click **Validate App** button
3. Click **Next**
4. Select your **Distribution Certificate** (should auto-select)
5. Click **Next**
6. Wait for validation (1-2 minutes)
7. If validation succeeds, click **Done**
8. If there are errors, fix them before proceeding

**Common validation issues:**
- Missing app icon (need 1024x1024px)
- Missing privacy descriptions
- Invalid bundle identifier

---

## ✅ Step 12: Distribute to App Store Connect

**Now we'll upload to Apple:**

1. In the **Organizer** window, select your archive
2. Click **Distribute App** button
3. Select **App Store Connect**
4. Click **Next**
5. Select **Upload**
6. Click **Next**
7. Select distribution options:
   - ☑ **Upload your app's symbols** (recommended - helps with crash reports)
   - ☑ **Manage Version and Build Number** (optional - lets Xcode manage it)
8. Click **Next**
9. Select signing:
   - Choose **Automatically manage signing** (recommended)
   - OR manually select your distribution certificate
10. Click **Next**
11. Review the summary
12. Click **Upload**
13. Wait for upload to complete (10-30 minutes depending on connection)
    - You'll see progress in Xcode
    - Don't close Xcode during upload

**When complete:** You'll see "Upload Succeeded"

---

## ✅ Step 13: Wait for Processing

**Apple needs to process your build:**

1. Go back to App Store Connect in your browser
2. Navigate to **My Apps** → **OpenAmbi Studio**
3. Click the **TestFlight** tab
4. You'll see your build with status: **Processing** (yellow indicator)
5. **Wait 10-60 minutes** for processing to complete
   - You'll receive an email when it's done
   - The status will change to **Ready to Submit**

**Don't proceed until processing is complete!**

---

## ✅ Step 14: Add Test Information

**Once processing is complete:**

1. In TestFlight, find your build (should show "Ready to Submit")
2. Click on the build
3. Scroll down to **Test Information**
4. Click **Add Test Information** or **Edit**
5. Fill in:
   - **What to Test:** 
     ```
     Please test the following:
     - Audio playback and mixing
     - Volume controls in the dock
     - Focus mode transitions
     - Background audio playback
     - UI interactions and gestures
     ```
   - **Feedback Email:** Your email address
   - **Privacy Policy URL:** (if you have one, or leave blank for now)
6. Click **Save**

---

## ✅ Step 15: Set Up Internal Testing (Optional)

**For quick testing with your team (up to 100 testers):**

1. In TestFlight, click **Internal Testing** tab
2. Click **+** to create a group (e.g., "Development Team")
3. Name your group
4. Click **Add Builds to Test**
5. Select your processed build
6. Click **Next**
7. Add testers:
   - Go to **Users and Access** → **Users**
   - Add team members (they need to accept invitation)
8. Click **Start Testing**

**Internal testers can test immediately (no Apple review needed)**

---

## ✅ Step 16: Set Up External Testing (Recommended)

**For beta testing with external users (up to 10,000 testers):**

1. In TestFlight, click **External Testing** tab
2. Click **+** to create a group (e.g., "Beta Testers")
3. Name your group
4. Click **Add Builds to Test**
5. Select your processed build
6. Click **Next**
7. Fill in **Test Information**:
   - **What to Test:** Same as Step 14
   - **Feedback Email:** Your email
   - **Privacy Policy URL:** (required for external testing)
     - If you don't have one, create a simple page or use a placeholder
8. Click **Next**
9. Review and click **Submit for Review**
10. **Wait for Apple's Beta App Review** (usually 24-48 hours for first submission)
    - You'll receive email updates
    - Subsequent builds are usually faster

---

## ✅ Step 17: Invite Testers

**Once your external testing is approved:**

1. Go to your test group in TestFlight
2. Click **Add Testers** or use the **Public Link**
3. **Option A - Email Invites:**
   - Enter email addresses
   - Testers will receive email invitations
4. **Option B - Public Link:**
   - Enable public link
   - Share the link with testers
   - They can join without email invitation

**Testers need to:**
1. Install **TestFlight** app from App Store (if they don't have it)
2. Accept the invitation or use the public link
3. Install your app from TestFlight
4. They'll receive notifications when you update the build

---

## ✅ Step 18: Update Your App (For Future Builds)

**When you want to upload a new version:**

1. In Xcode, go to **General** tab
2. Increment the **Build** number (e.g., from `1` to `2`)
3. Follow Steps 8-12 again (Clean → Archive → Upload)
4. Once processed, add the new build to your TestFlight groups
5. Testers will automatically be notified of the update

---

## 🎉 You're Done!

Your app is now on TestFlight! Testers can download and test it.

## 📋 Quick Checklist

- [ ] Apple Developer Account enrolled
- [ ] Bundle identifier changed from `com.example.openambistudio`
- [ ] Version and build numbers set
- [ ] Signing configured with your team
- [ ] Background audio capability added
- [ ] App created in App Store Connect
- [ ] App archived successfully
- [ ] Build uploaded to App Store Connect
- [ ] Build processed by Apple
- [ ] Test information added
- [ ] Testers invited (internal or external)

## 🆘 Troubleshooting

**"No accounts with App Store Connect access"**
- Go to Xcode → Settings → Accounts
- Make sure you're signed in with the correct Apple ID
- Verify your account is enrolled in Developer Program

**"Bundle identifier is already in use"**
- The bundle ID must be unique
- Change it in Xcode to something unique
- Update it in App Store Connect to match

**"Invalid Bundle" or validation errors**
- Check that deployment target is correct
- Ensure app icons are present (1024x1024px required)
- Verify signing is configured correctly

**Upload fails**
- Check your internet connection
- Try using **Transporter** app (Mac App Store) as alternative
- Check Xcode → Window → Organizer for detailed errors

**Need help?** Let me know which step you're on and what error you're seeing!

