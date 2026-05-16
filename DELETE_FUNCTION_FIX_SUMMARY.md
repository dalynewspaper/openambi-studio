# Delete Function Fix Summary

## Problem Identified

The delete function in your TestFlight app is not working correctly - deleted sound items reappear. This is likely due to one or more of these issues:

1. **Delete function may be doing hard delete instead of soft delete** - Some versions of the delete function do `DELETE FROM` instead of `UPDATE ... SET deleted_at = NOW()`
2. **SELECT policy may not be filtering deleted records** - If the SELECT policy doesn't check `deleted_at IS NULL`, deleted records will still appear
3. **RLS policies may be blocking the delete function** - Even with `SECURITY DEFINER`, there can be issues if policies aren't properly configured
4. **Update policy may allow updating deleted records** - This could cause deleted records to reappear if they're accidentally updated

## Root Cause Analysis

Based on the code review:

- The app expects **soft delete** (setting `deleted_at` timestamp)
- The app queries with `deleted_at=is.null` filter
- The SELECT policy should exclude `deleted_at IS NOT NULL` records
- The delete function should do `UPDATE ... SET deleted_at = NOW()` not `DELETE FROM`

## Solution

I've created two SQL scripts:

### 1. `AUDIT_CURRENT_DATABASE_STATE.sql`
**Run this FIRST** to see what's currently in your database:
- Lists all functions and their types (hard delete vs soft delete)
- Lists all RLS policies and checks if they filter deleted records
- Shows current RLS status
- Identifies potential issues

### 2. `COMPREHENSIVE_DATABASE_AUDIT_AND_FIX.sql`
**Run this SECOND** to fix all issues:
- Drops and recreates all functions with bulletproof implementations
- Drops and recreates all RLS policies with proper deleted_at filtering
- Ensures delete function does SOFT DELETE (sets deleted_at)
- Ensures SELECT policy excludes deleted records
- Ensures UPDATE policy prevents updating deleted records
- Makes delete function idempotent (safe to call multiple times)

## Key Fixes Applied

### Delete Function
```sql
-- CRITICAL: Performs SOFT DELETE by setting deleted_at
UPDATE user_recordings
SET 
    deleted_at = NOW(),
    updated_at = NOW()
WHERE id = p_id 
  AND user_id = v_user_id 
  AND deleted_at IS NULL;  -- Only delete if not already deleted
```

### SELECT Policy
```sql
-- CRITICAL: Must exclude deleted_at IS NOT NULL
CREATE POLICY "Users can view own recordings" ON user_recordings
    FOR SELECT 
    TO authenticated
    USING (
        auth.uid() IS NOT NULL
        AND auth.uid() = user_id
        AND deleted_at IS NULL  -- CRITICAL: Exclude soft-deleted records
    );
```

### UPDATE Policy
```sql
-- CRITICAL: Must prevent updating deleted records
CREATE POLICY "Users can update own recordings" ON user_recordings
    FOR UPDATE 
    TO authenticated
    USING (
        auth.uid() IS NOT NULL
        AND auth.uid() = user_id
        AND deleted_at IS NULL  -- CRITICAL: Cannot update deleted records
    )
    WITH CHECK (
        auth.uid() IS NOT NULL
        AND auth.uid() = user_id
        AND deleted_at IS NULL  -- CRITICAL: Cannot set deleted_at via UPDATE
    );
```

## Future-Proofing for Public Usernames

The fix script includes notes for future implementation of public usernames and sharing features:

- When ready, add `public_username` column (or separate `user_profiles` table)
- Add `is_public` boolean column to `user_recordings`
- Update SELECT policy to allow public access when `is_public = true`
- Add unique constraint on `public_username`
- Create index on `public_username` for fast lookups

## Testing Steps

After running the fix script:

1. **Test Delete**: Delete a recording in the app
2. **Verify it disappears**: The recording should immediately disappear from the list
3. **Refresh the app**: Close and reopen the app - deleted recording should NOT reappear
4. **Check database**: Run a query to verify `deleted_at` is set:
   ```sql
   SELECT id, name, deleted_at 
   FROM user_recordings 
   WHERE deleted_at IS NOT NULL 
   ORDER BY deleted_at DESC;
   ```

## Important Notes

- All functions use `SECURITY DEFINER` to bypass RLS reliably
- All functions still verify ownership before operations
- Delete function is idempotent (safe to call multiple times)
- The fix maintains backward compatibility with existing data

## Next Steps

1. Run `AUDIT_CURRENT_DATABASE_STATE.sql` in Supabase SQL Editor
2. Review the audit results
3. Run `COMPREHENSIVE_DATABASE_AUDIT_AND_FIX.sql` in Supabase SQL Editor
4. Test delete functionality in TestFlight app
5. Verify deleted recordings don't reappear

