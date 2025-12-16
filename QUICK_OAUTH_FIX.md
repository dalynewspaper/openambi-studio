# 🚨 Quick Fix: OAuth Configuration Required

## Current Error

You're seeing: **"Unsupported provider: missing OAuth secret"**

This means the OAuth providers (Apple/Google) need to be configured in Supabase.

---

## ⚡ Quick Solution

### Option 1: Configure OAuth in Supabase (Recommended)

Follow the detailed guide in `OAUTH_SETUP_GUIDE.md`, but here's the quick version:

#### For Apple Sign In:
1. Go to Supabase Dashboard → Authentication → Providers
2. Toggle **Apple** to ON
3. You'll need (from Apple Developer Portal):
   - Service ID
   - Team ID  
   - Key ID
   - Private Key (.p8 file)

#### For Google Sign In:
1. Go to Supabase Dashboard → Authentication → Providers
2. Toggle **Google** to ON
3. Enter:
   - Client ID (from Google Cloud Console)
   - Client Secret (from Google Cloud Console)

**See `OAUTH_SETUP_GUIDE.md` for detailed step-by-step instructions.**

---

### Option 2: Temporary Workaround (For Testing)

If you want to test the app flow without OAuth setup, you can temporarily add back email/password authentication. However, since you specifically requested only Apple/Google, you'll need to configure OAuth.

---

## 🔍 Why This Error Happens

The app is trying to authenticate with Supabase using Apple/Google OAuth, but Supabase doesn't have the OAuth credentials configured yet. Supabase needs:
- **Apple**: Service ID, Team ID, Key ID, and Private Key
- **Google**: Client ID and Client Secret

---

## ✅ Next Steps

1. **Configure Apple Sign In in Supabase** (see `OAUTH_SETUP_GUIDE.md` Step 2)
2. **Configure Google Sign In in Supabase** (see `OAUTH_SETUP_GUIDE.md` Step 3)
3. **Set up redirect URLs** in Supabase (see `OAUTH_SETUP_GUIDE.md` Step 4)
4. **Test again** - the errors should be resolved

---

## 📝 Important Notes

- **Apple Sign In** requires a physical device (doesn't work in simulator)
- **Bundle Identifier** must match: `co.fourthquarterstudio.openambi`
- **Redirect URL** in Supabase must be: `co.fourthquarterstudio.openambi:/auth/callback`

---

Once OAuth is configured in Supabase, the authentication should work! 🎉
