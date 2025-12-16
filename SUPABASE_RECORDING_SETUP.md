# 🎤 Supabase Recording Setup Guide

## Quick Setup for User Recordings

To enable user recording functionality, you need to set up the storage bucket and database table in Supabase.

---

## 📦 Step 1: Create Storage Bucket

### Option A: Using SQL (Recommended - Fastest)

1. **Go to Supabase SQL Editor**
   - Navigate to: https://supabase.com/dashboard
   - Select your project
   - Click "SQL Editor" in the left sidebar
   - Click "New query"

2. **Run this SQL:**
   ```sql
   -- Create user-recordings storage bucket
   INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
   VALUES (
       'user-recordings',
       'user-recordings',
       false,
       52428800, -- 50 MB
       ARRAY['audio/m4a', 'audio/mpeg', 'audio/x-m4a']
   )
   ON CONFLICT (id) DO NOTHING;
   ```

3. **Click "Run"** (or press Cmd+Enter)

4. **Verify bucket was created:**
   ```sql
   SELECT * FROM storage.buckets WHERE id = 'user-recordings';
   ```

### Option B: Using Dashboard UI

1. **Go to Supabase Dashboard**
   - Navigate to: https://supabase.com/dashboard
   - Select your project

2. **Open Storage**
   - Click "Storage" in the left sidebar
   - Click "New bucket"

3. **Create `user-recordings` Bucket**
   - **Name**: `user-recordings` (must match exactly)
   - **Public**: ❌ **Uncheck** (keep it private)
   - **File size limit**: 50 MB (recommended)
   - **Allowed MIME types**: `audio/m4a`, `audio/mpeg`, `audio/x-m4a`
   - Click "Create bucket"

### Set Bucket Policies (Required for both options)

After creating the bucket, set up policies:

1. **Go to SQL Editor** (easiest method)
2. **Run the storage policies SQL** from `USER_RECORDINGS_DATABASE_SCHEMA.sql` (storage policies section at the bottom)

---

## 🗄️ Step 2: Create Database Table

1. **Go to SQL Editor**
   - Click "SQL Editor" in the left sidebar
   - Click "New query"

2. **Run the Schema SQL**
   - Open `USER_RECORDINGS_DATABASE_SCHEMA.sql`
   - Copy the entire contents
   - Paste into SQL Editor
   - Click "Run" (or press Cmd+Enter)

3. **Verify Table Created**
   - Go to "Table Editor"
   - You should see `user_recordings` table
   - Check that all columns are present

---

## ✅ Step 3: Verify Setup

### Check Storage Bucket
- ✅ Bucket name: `user-recordings`
- ✅ Private (not public)
- ✅ Policies configured

### Check Database Table
- ✅ Table name: `user_recordings`
- ✅ RLS enabled
- ✅ Policies configured

### Test Upload
1. Record a sound in the app
2. Try to save it
3. Should upload successfully

---

## 🔧 Troubleshooting

### Error: "Bucket not found"
- **Solution**: Create the `user-recordings` bucket in Supabase Storage
- Make sure the name matches exactly: `user-recordings` (with hyphen)

### Error: "Permission denied"
- **Solution**: Check storage bucket policies
- Make sure RLS policies allow authenticated users to upload

### Error: "Table not found"
- **Solution**: Run the SQL schema from `USER_RECORDINGS_DATABASE_SCHEMA.sql`
- Verify the table exists in Table Editor

### Error: "Unauthorized"
- **Solution**: User needs to sign in
- Check that authentication is working

---

## 📝 Quick SQL Commands

### Create Bucket (if not using UI)
```sql
-- Note: Buckets are typically created via UI, but you can use this if needed
INSERT INTO storage.buckets (id, name, public)
VALUES ('user-recordings', 'user-recordings', false);
```

### Check if Bucket Exists
```sql
SELECT * FROM storage.buckets WHERE id = 'user-recordings';
```

### Check if Table Exists
```sql
SELECT * FROM information_schema.tables 
WHERE table_name = 'user_recordings';
```

---

## 🎯 Next Steps

Once setup is complete:
1. ✅ Users can record sounds
2. ✅ Recordings upload to Supabase
3. ✅ Recordings appear in user's library
4. ✅ Recordings sync across devices

---

**Need Help?** Check the `USER_RECORDINGS_DATABASE_SCHEMA.sql` file for complete setup instructions.

