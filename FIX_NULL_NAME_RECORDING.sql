-- FIX NULL NAME RECORDING
-- The recording with id 5c07d3e6-b51e-4ffc-886d-36d1f56c2451 has name: null
-- This is causing issues. Let's fix it.

-- Update the recording with a default name if it's null
UPDATE user_recordings
SET name = COALESCE(name, 'Untitled Recording'),
    category = COALESCE(category, 'My Recordings'),
    updated_at = NOW()
WHERE id = '5c07d3e6-b51e-4ffc-886d-36d1f56c2451'
  AND (name IS NULL OR category IS NULL);

-- Verify the fix
SELECT 
    'Fixed Recording' as check_type,
    id,
    name,
    category,
    icon,
    created_at
FROM user_recordings
WHERE id = '5c07d3e6-b51e-4ffc-886d-36d1f56c2451';

