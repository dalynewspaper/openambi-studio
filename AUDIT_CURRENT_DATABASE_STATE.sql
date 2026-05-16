-- ============================================================================
-- DATABASE AUDIT - CURRENT STATE REPORT
-- Run this FIRST to see what's currently in your database
-- Then run COMPREHENSIVE_DATABASE_AUDIT_AND_FIX.sql to fix issues
-- ============================================================================

-- ============================================================================
-- SECTION 1: FUNCTIONS AUDIT
-- ============================================================================

SELECT 
    '=== SECTION 1: FUNCTIONS ===' as section,
    '' as detail;

SELECT 
    'Function Name' as name,
    pg_get_function_arguments(oid) as arguments,
    CASE WHEN prosecdef THEN 'SECURITY DEFINER' ELSE 'SECURITY INVOKER' END as security_type,
    proowner::regrole as owner,
    CASE 
        WHEN proname = 'delete_user_recording' THEN 
            CASE 
                WHEN prosrc LIKE '%deleted_at%' AND prosrc LIKE '%UPDATE%' THEN 'SOFT DELETE (sets deleted_at) ✓'
                WHEN prosrc LIKE '%DELETE FROM%' THEN 'HARD DELETE (removes row) ✗'
                ELSE 'UNKNOWN DELETE TYPE'
            END
        ELSE ''
    END as delete_type,
    LEFT(prosrc, 200) as source_preview
FROM pg_proc
WHERE pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
  AND (
    proname LIKE '%recording%' 
    OR proname LIKE '%user_recordings%'
    OR proname IN ('set_user_id_from_auth', 'update_updated_at_column')
  )
ORDER BY proname;

-- ============================================================================
-- SECTION 2: RLS POLICIES AUDIT
-- ============================================================================

SELECT 
    '=== SECTION 2: RLS POLICIES ===' as section,
    '' as detail;

SELECT 
    'Policy Name' as name,
    cmd as operation,
    roles::text as roles,
    qual as using_clause,
    with_check as with_check_clause,
    CASE 
        WHEN cmd = 'SELECT' AND qual LIKE '%deleted_at IS NULL%' THEN 'Filters deleted ✓'
        WHEN cmd = 'SELECT' AND qual NOT LIKE '%deleted_at%' THEN 'Missing deleted_at filter ✗'
        WHEN cmd = 'UPDATE' AND qual LIKE '%deleted_at IS NULL%' THEN 'Prevents updating deleted ✓'
        WHEN cmd = 'UPDATE' AND qual NOT LIKE '%deleted_at%' THEN 'Allows updating deleted ✗'
        ELSE ''
    END as security_check
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'user_recordings'
ORDER BY cmd, policyname;

-- ============================================================================
-- SECTION 3: RLS STATUS
-- ============================================================================

SELECT 
    '=== SECTION 3: RLS STATUS ===' as section,
    '' as detail;

SELECT 
    'Table Name' as name,
    CASE WHEN rowsecurity THEN 'ENABLED ✓' ELSE 'DISABLED ✗' END as status
FROM pg_tables
WHERE schemaname = 'public' 
  AND tablename = 'user_recordings';

-- ============================================================================
-- SECTION 4: TRIGGERS AUDIT
-- ============================================================================

SELECT 
    '=== SECTION 4: TRIGGERS ===' as section,
    '' as detail;

SELECT 
    'Trigger Name' as name,
    event_manipulation as event,
    action_timing as timing,
    action_statement as statement
FROM information_schema.triggers
WHERE event_object_schema = 'public'
  AND event_object_table = 'user_recordings'
ORDER BY trigger_name;

-- ============================================================================
-- SECTION 5: STORAGE POLICIES AUDIT
-- ============================================================================

SELECT 
    '=== SECTION 5: STORAGE POLICIES (user-recordings bucket) ===' as section,
    '' as detail;

SELECT 
    'Policy Name' as name,
    cmd as operation,
    roles::text as roles,
    qual as using_clause
FROM pg_policies
WHERE schemaname = 'storage' 
  AND tablename = 'objects'
  AND policyname LIKE '%recording%'
ORDER BY cmd, policyname;

-- ============================================================================
-- SECTION 6: CHECK FOR DELETED RECORDINGS
-- ============================================================================

SELECT 
    '=== SECTION 6: DELETED RECORDINGS CHECK ===' as section,
    '' as detail;

-- Count total recordings
SELECT 
    'Total Recordings' as metric,
    COUNT(*) as count
FROM user_recordings;

-- Count deleted recordings
SELECT 
    'Deleted Recordings (deleted_at IS NOT NULL)' as metric,
    COUNT(*) as count
FROM user_recordings
WHERE deleted_at IS NOT NULL;

-- Count active recordings
SELECT 
    'Active Recordings (deleted_at IS NULL)' as metric,
    COUNT(*) as count
FROM user_recordings
WHERE deleted_at IS NULL;

-- Sample deleted recordings (if any)
SELECT 
    'Sample Deleted Recordings' as metric,
    id,
    name,
    user_id,
    deleted_at,
    created_at
FROM user_recordings
WHERE deleted_at IS NOT NULL
ORDER BY deleted_at DESC
LIMIT 10;

-- ============================================================================
-- SECTION 7: FUNCTION PERMISSIONS
-- ============================================================================

SELECT 
    '=== SECTION 7: FUNCTION PERMISSIONS ===' as section,
    '' as detail;

SELECT 
    p.proname as function_name,
    r.rolname as granted_to,
    CASE WHEN has_function_privilege(r.oid, p.oid, 'EXECUTE') THEN 'YES ✓' ELSE 'NO ✗' END as can_execute
FROM pg_proc p
CROSS JOIN pg_roles r
WHERE p.pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
  AND p.proname IN ('insert_user_recording', 'update_user_recording', 'delete_user_recording')
  AND r.rolname IN ('authenticated', 'anon', 'postgres')
ORDER BY p.proname, r.rolname;

-- ============================================================================
-- SECTION 8: POTENTIAL ISSUES SUMMARY
-- ============================================================================

SELECT 
    '=== SECTION 8: POTENTIAL ISSUES ===' as section,
    '' as detail;

-- Check if delete function does hard delete instead of soft delete
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_proc 
            WHERE proname = 'delete_user_recording' 
            AND prosrc LIKE '%DELETE FROM%'
            AND prosrc NOT LIKE '%deleted_at%'
        ) THEN 'ISSUE: delete_user_recording does HARD DELETE instead of SOFT DELETE'
        WHEN EXISTS (
            SELECT 1 FROM pg_proc 
            WHERE proname = 'delete_user_recording' 
            AND prosrc LIKE '%UPDATE%' 
            AND prosrc LIKE '%deleted_at%'
        ) THEN 'OK: delete_user_recording does SOFT DELETE'
        ELSE 'WARNING: Cannot determine delete_user_recording type'
    END as delete_function_check;

-- Check if SELECT policy filters deleted records
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_policies 
            WHERE tablename = 'user_recordings' 
            AND cmd = 'SELECT'
            AND qual LIKE '%deleted_at IS NULL%'
        ) THEN 'OK: SELECT policy filters deleted records'
        ELSE 'ISSUE: SELECT policy does NOT filter deleted records'
    END as select_policy_check;

-- Check if UPDATE policy prevents updating deleted records
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_policies 
            WHERE tablename = 'user_recordings' 
            AND cmd = 'UPDATE'
            AND qual LIKE '%deleted_at IS NULL%'
        ) THEN 'OK: UPDATE policy prevents updating deleted records'
        ELSE 'ISSUE: UPDATE policy allows updating deleted records'
    END as update_policy_check;

-- ============================================================================
-- END OF AUDIT
-- ============================================================================

SELECT 
    '=== AUDIT COMPLETE ===' as section,
    'Review the results above, then run COMPREHENSIVE_DATABASE_AUDIT_AND_FIX.sql to fix any issues' as next_step;

