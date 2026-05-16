-- ============================================================================
-- VERIFICATION SCRIPT - Verify Delete Function Fix
-- Run this after COMPREHENSIVE_DATABASE_AUDIT_AND_FIX.sql to confirm everything works
-- ============================================================================

-- ============================================================================
-- VERIFICATION 1: Check Delete Function Does Soft Delete
-- ============================================================================

SELECT 
    '=== VERIFICATION 1: Delete Function Type ===' as check_type,
    '' as detail;

SELECT 
    CASE 
        WHEN prosrc LIKE '%UPDATE%' 
         AND prosrc LIKE '%deleted_at%' 
         AND prosrc LIKE '%SET deleted_at = NOW()%'
         AND prosrc NOT LIKE '%DELETE FROM%' THEN '✓ CORRECT: Does SOFT DELETE (sets deleted_at)'
        WHEN prosrc LIKE '%DELETE FROM%' THEN '✗ WRONG: Does HARD DELETE (removes row)'
        ELSE '⚠ WARNING: Cannot determine delete type'
    END as delete_function_status,
    LEFT(prosrc, 300) as function_preview
FROM pg_proc
WHERE proname = 'delete_user_recording'
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

-- ============================================================================
-- VERIFICATION 2: Check SELECT Policy Filters Deleted Records
-- ============================================================================

SELECT 
    '=== VERIFICATION 2: SELECT Policy Filters Deleted ===' as check_type,
    '' as detail;

SELECT 
    policyname,
    CASE 
        WHEN qual LIKE '%deleted_at IS NULL%' THEN '✓ CORRECT: Filters deleted records'
        WHEN qual LIKE '%deleted_at%' THEN '⚠ PARTIAL: Mentions deleted_at but may not filter correctly'
        ELSE '✗ MISSING: Does not filter deleted records'
    END as policy_status,
    qual as using_clause
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'user_recordings'
  AND cmd = 'SELECT';

-- ============================================================================
-- VERIFICATION 3: Check UPDATE Policy Prevents Updating Deleted
-- ============================================================================

SELECT 
    '=== VERIFICATION 3: UPDATE Policy Prevents Updating Deleted ===' as check_type,
    '' as detail;

SELECT 
    policyname,
    CASE 
        WHEN qual LIKE '%deleted_at IS NULL%' 
         AND with_check LIKE '%deleted_at IS NULL%' THEN '✓ CORRECT: Prevents updating deleted records'
        WHEN qual LIKE '%deleted_at IS NULL%' THEN '⚠ PARTIAL: Using clause checks, but with_check may allow'
        ELSE '✗ MISSING: Does not prevent updating deleted records'
    END as policy_status,
    qual as using_clause,
    with_check as with_check_clause
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'user_recordings'
  AND cmd = 'UPDATE';

-- ============================================================================
-- VERIFICATION 4: Check All Functions Use SECURITY DEFINER
-- ============================================================================

SELECT 
    '=== VERIFICATION 4: Functions Use SECURITY DEFINER ===' as check_type,
    '' as detail;

SELECT 
    proname as function_name,
    CASE 
        WHEN prosecdef THEN '✓ SECURITY DEFINER'
        ELSE '✗ SECURITY INVOKER (may have RLS issues)'
    END as security_status
FROM pg_proc
WHERE pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
  AND proname IN ('insert_user_recording', 'update_user_recording', 'delete_user_recording')
ORDER BY proname;

-- ============================================================================
-- VERIFICATION 5: Check Function Permissions
-- ============================================================================

SELECT 
    '=== VERIFICATION 5: Function Permissions ===' as check_type,
    '' as detail;

SELECT 
    p.proname as function_name,
    r.rolname as role,
    CASE 
        WHEN has_function_privilege(r.oid, p.oid, 'EXECUTE') THEN '✓ Can execute'
        ELSE '✗ Cannot execute'
    END as permission_status
FROM pg_proc p
CROSS JOIN pg_roles r
WHERE p.pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
  AND p.proname IN ('insert_user_recording', 'update_user_recording', 'delete_user_recording')
  AND r.rolname IN ('authenticated', 'anon')
ORDER BY p.proname, r.rolname;

-- ============================================================================
-- VERIFICATION 6: Test Query - Should Only Return Non-Deleted Records
-- ============================================================================

SELECT 
    '=== VERIFICATION 6: Test Query (as authenticated user) ===' as check_type,
    'Note: This will return 0 rows in SQL editor (no auth context), but should work in app' as detail;

-- This query simulates what the app does
-- In the app with auth context, this should only return records where deleted_at IS NULL
SELECT 
    COUNT(*) as total_recordings,
    COUNT(*) FILTER (WHERE deleted_at IS NULL) as active_recordings,
    COUNT(*) FILTER (WHERE deleted_at IS NOT NULL) as deleted_recordings
FROM user_recordings;

-- ============================================================================
-- VERIFICATION 7: Check for Orphaned Deleted Records
-- ============================================================================

SELECT 
    '=== VERIFICATION 7: Deleted Records Check ===' as check_type,
    '' as detail;

-- Show sample of deleted records (these should NOT appear in app)
SELECT 
    id,
    name,
    user_id,
    deleted_at,
    created_at,
    'This record should NOT appear in app queries' as note
FROM user_recordings
WHERE deleted_at IS NOT NULL
ORDER BY deleted_at DESC
LIMIT 5;

-- ============================================================================
-- VERIFICATION 8: Overall Status Summary
-- ============================================================================

SELECT 
    '=== VERIFICATION 8: Overall Status ===' as check_type,
    '' as detail;

SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_proc 
            WHERE proname = 'delete_user_recording' 
            AND prosecdef = true
            AND prosrc LIKE '%UPDATE%'
            AND prosrc LIKE '%deleted_at%'
            AND prosrc LIKE '%SET deleted_at = NOW()%'
        )
        AND EXISTS (
            SELECT 1 FROM pg_policies 
            WHERE tablename = 'user_recordings' 
            AND cmd = 'SELECT'
            AND qual LIKE '%deleted_at IS NULL%'
        )
        AND EXISTS (
            SELECT 1 FROM pg_policies 
            WHERE tablename = 'user_recordings' 
            AND cmd = 'UPDATE'
            AND qual LIKE '%deleted_at IS NULL%'
        )
        THEN '✓ ALL CHECKS PASSED - Delete function should work correctly'
        ELSE '⚠ SOME CHECKS FAILED - Review the details above'
    END as overall_status;

-- ============================================================================
-- TESTING INSTRUCTIONS
-- ============================================================================

SELECT 
    '=== TESTING INSTRUCTIONS ===' as section,
    '' as detail;

SELECT 
    '1. Test Delete in App' as step,
    'Delete a recording in your TestFlight app. It should disappear immediately.' as instruction
UNION ALL
SELECT 
    '2. Refresh App' as step,
    'Close and reopen the app. The deleted recording should NOT reappear.' as instruction
UNION ALL
SELECT 
    '3. Verify Database' as step,
    'Run: SELECT * FROM user_recordings WHERE deleted_at IS NOT NULL; to see deleted records.' as instruction
UNION ALL
SELECT 
    '4. Check App Query' as step,
    'The app query with deleted_at=is.null should only return active recordings.' as instruction;

