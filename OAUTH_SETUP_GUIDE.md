# 🔐 OAuth Setup Guide - Apple Sign In & Google Sign In

## ✅ Implementation Complete

The authentication system has been updated to use **only** OAuth providers:
- ✅ **Sign in with Apple**
- ✅ **Sign in with Google**
- ❌ Email/password authentication removed

---

## 📋 Supabase Configuration

### Step 1: Enable OAuth Providers in Supabase

1. Go to your Supabase Dashboard: https://app.supabase.com
2. Select your project
3. Go to **Authentication** → **Providers**
4. Enable **Apple** provider:
   - Toggle **Apple** to ON
   - Configure Apple OAuth settings (see below)
5. Enable **Google** provider:
   - Toggle **Google** to ON
   - Configure Google OAuth settings (see below)

### Step 2: Configure Apple Sign In

#### In Supabase Dashboard:
1. Go to **Authentication** → **Providers** → **Apple**
2. You'll need:
   - **Service ID** (from Apple Developer)
   - **Team ID** (from Apple Developer)
   - **Key ID** (from Apple Developer)
   - **Private Key** (from Apple Developer)

#### In Apple Developer Portal:
1. Go to https://developer.apple.com/account
2. Create a **Service ID**:
   - Identifiers → Services IDs → Register new
   - Description: "OpenAmbi Authentication"
   - Identifier: `com.yourcompany.openambi.auth`
3. Configure the Service ID:
   - Enable "Sign in with Apple"
   - Add your domain and redirect URLs
   - Add callback URL: `https://[your-supabase-project].supabase.co/auth/v1/callback`
4. Create a **Key**:
   - Keys → Create new key
   - Enable "Sign in with Apple"
   - Download the key (`.p8` file) - **you can only download once!**
   - Note the **Key ID**
5. Get your **Team ID** from the top right of the Apple Developer portal

#### Add to Supabase:
- Service ID: `com.yourcompany.openambi.auth`
- Team ID: `YOUR_TEAM_ID`
- Key ID: `YOUR_KEY_ID`
- Private Key: Paste the contents of the `.p8` file

### Step 3: Configure Google Sign In

#### In Google Cloud Console:
1. Go to https://console.cloud.google.com
2. Create a new project or select existing
3. Enable **Google+ API**:
   - APIs & Services → Library
   - Search for "Google+ API"
   - Click Enable
4. Create **OAuth 2.0 Credentials**:
   - APIs & Services → Credentials
   - Create Credentials → OAuth client ID
   - Application type: **Web application**
   - Name: "OpenAmbi Web"
   - Authorized redirect URIs:
     - `https://[your-supabase-project].supabase.co/auth/v1/callback`
   - Click Create
   - Copy the **Client ID** and **Client Secret**

#### Add to Supabase:
1. Go to **Authentication** → **Providers** → **Google**
2. Enter:
   - **Client ID**: From Google Cloud Console
   - **Client Secret**: From Google Cloud Console

### Step 4: Configure Redirect URLs

In Supabase Dashboard → **Authentication** → **URL Configuration**:

- **Site URL**: `com.yourcompany.openambi:/auth/callback`
- **Redirect URLs**: Add:
  - `com.yourcompany.openambi:/auth/callback`
  - `https://[your-supabase-project].supabase.co/auth/v1/callback`

---

## 📱 iOS App Configuration

### Step 1: Add URL Scheme to Info.plist

The app needs to handle OAuth callbacks. Add this to `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.yourcompany.openambi</string>
        </array>
    </dict>
</array>
```

**Note**: Replace `com.yourcompany.openambi` with your actual bundle identifier.

### Step 2: Enable Sign in with Apple Capability

1. In Xcode, select your project
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **Sign in with Apple**

### Step 3: Update Bundle Identifier

Make sure your bundle identifier matches what you configured in:
- Apple Developer Portal (Service ID)
- Supabase redirect URLs

---

## 🧪 Testing

### Test Apple Sign In

1. Run the app on a **physical device** (Sign in with Apple doesn't work in simulator)
2. Tap "Sign in with Apple"
3. Complete the Apple authentication flow
4. You should be signed in and see the main app

### Test Google Sign In

1. Run the app
2. Tap "Continue with Google"
3. A browser window should open
4. Sign in with your Google account
5. You should be redirected back to the app and signed in

---

## 🔧 Troubleshooting

### "Sign in with Apple" button doesn't appear

- ✅ Make sure you're testing on a **physical device** (not simulator)
- ✅ Verify "Sign in with Apple" capability is added in Xcode
- ✅ Check that your Apple Developer account is configured

### Google Sign In opens browser but doesn't redirect back

- ✅ Check redirect URL in Supabase matches bundle identifier
- ✅ Verify URL scheme is added to Info.plist
- ✅ Check that redirect URL is added to Supabase allowed URLs

### "Invalid redirect URL" error

- ✅ Verify redirect URL in Supabase matches: `com.yourcompany.openambi:/auth/callback`
- ✅ Make sure bundle identifier matches
- ✅ Check URL scheme in Info.plist

### Apple Sign In fails with "Invalid client"

- ✅ Verify Service ID, Team ID, Key ID, and Private Key in Supabase
- ✅ Make sure the `.p8` key file is correctly pasted (no extra spaces)
- ✅ Check that the key hasn't expired

### Google Sign In fails

- ✅ Verify Client ID and Client Secret in Supabase
- ✅ Check that Google+ API is enabled in Google Cloud Console
- ✅ Verify redirect URI matches exactly in both Google Console and Supabase

---

## 📝 Important Notes

1. **Apple Sign In** requires a physical device - it won't work in the iOS Simulator
2. **Bundle Identifier** must match across:
   - Xcode project
   - Apple Developer Service ID
   - Supabase redirect URLs
3. **Redirect URLs** must be exact matches (case-sensitive)
4. **Private Key** for Apple can only be downloaded once - keep it safe!

---

## ✅ Checklist

- [ ] Apple provider enabled in Supabase
- [ ] Google provider enabled in Supabase
- [ ] Apple Service ID created and configured
- [ ] Apple Key created and added to Supabase
- [ ] Google OAuth credentials created
- [ ] Google Client ID/Secret added to Supabase
- [ ] Redirect URLs configured in Supabase
- [ ] URL scheme added to Info.plist
- [ ] Sign in with Apple capability added in Xcode
- [ ] Bundle identifier matches everywhere
- [ ] Tested on physical device (Apple Sign In)
- [ ] Tested Google Sign In

---

Once configured, users can sign in with either Apple or Google! 🎉
