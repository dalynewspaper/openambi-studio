# 🔧 Xcode Setup Guide - Adding Authentication Files

## Files to Add

1. `openambi-studio/Services/AuthManager.swift`
2. `openambi-studio/AuthenticationView.swift`

---

## Method 1: Add Files via Xcode UI (Recommended)

### Step 1: Open Xcode Project

1. Open `openambi-studio.xcodeproj` in Xcode
2. Wait for Xcode to finish indexing

### Step 2: Add AuthManager.swift

1. In the **Project Navigator** (left sidebar), find the `Services` folder
2. Right-click on the `Services` folder
3. Select **"Add Files to 'openambi-studio'..."**
4. Navigate to: `openambi-studio/Services/AuthManager.swift`
5. **Important**: Make sure these options are checked:
   - ✅ **"Copy items if needed"** (uncheck this - file is already in the right place)
   - ✅ **"Add to targets: openambi-studio"** (this is critical!)
6. Click **Add**

### Step 3: Add AuthenticationView.swift

1. In the **Project Navigator**, find the `openambi-studio` folder (root level)
2. Right-click on the `openambi-studio` folder
3. Select **"Add Files to 'openambi-studio'..."**
4. Navigate to: `openambi-studio/AuthenticationView.swift`
5. **Important**: Make sure these options are checked:
   - ✅ **"Copy items if needed"** (uncheck this - file is already in the right place)
   - ✅ **"Add to targets: openambi-studio"** (this is critical!)
6. Click **Add**

### Step 4: Verify Files Are Added

1. In Project Navigator, you should see:
   - `Services/AuthManager.swift` ✅
   - `AuthenticationView.swift` ✅
2. Click on each file to verify they open correctly
3. Try building the project (⌘B) to check for errors

---

## Method 2: Drag and Drop (Alternative)

### Step 1: Show Files in Finder

1. In Finder, navigate to: `openambi-studio/openambi-studio/Services/`
2. You should see `AuthManager.swift`

### Step 2: Drag to Xcode

1. Open Xcode with your project
2. In Project Navigator, find the `Services` folder
3. Drag `AuthManager.swift` from Finder into the `Services` folder in Xcode
4. In the dialog that appears:
   - ✅ Check **"Copy items if needed"** (uncheck - file is already there)
   - ✅ Check **"Add to targets: openambi-studio"**
   - Click **Finish**

### Step 3: Repeat for AuthenticationView

1. In Finder, navigate to: `openambi-studio/openambi-studio/`
2. Drag `AuthenticationView.swift` to the root `openambi-studio` folder in Xcode
3. Make sure **"Add to targets: openambi-studio"** is checked

---

## Method 3: Automatic (I'll add them to project file)

If you prefer, I can automatically add the file references to the project.pbxproj file. This is faster but requires you to trust the automated process.

---

## ✅ Verification Checklist

After adding files, verify:

- [ ] `AuthManager.swift` appears in Project Navigator under `Services/`
- [ ] `AuthenticationView.swift` appears in Project Navigator at root level
- [ ] Both files can be opened and viewed in Xcode
- [ ] Project builds without errors (⌘B)
- [ ] No red error indicators next to file names

---

## 🐛 Troubleshooting

### "File not found" error

- Make sure the file path is correct
- Verify the file exists in Finder
- Try removing and re-adding the file

### Build errors about missing types

- Verify **"Add to targets: openambi-studio"** was checked
- Clean build folder: Product → Clean Build Folder (⇧⌘K)
- Rebuild: Product → Build (⌘B)

### Files appear but are grayed out

- The files might not be added to the target
- Select the file in Project Navigator
- In File Inspector (right sidebar), check **Target Membership**
- Make sure **openambi-studio** is checked

---

## 🚀 Next Steps After Adding Files

1. **Build the project** (⌘B) to check for compilation errors
2. **Run the app** (⌘R) to test authentication
3. **Set up Supabase** (follow `AUTHENTICATION_SETUP.md`)

---

Choose your preferred method above! Method 1 (Xcode UI) is the safest and most reliable.
