# Tech Spec: Launch Video + Composition (Phase A/B)

**Status:** Ready for implementation  
**Audience:** iOS + Supabase maintainers  
**Outcome:** Video import survives sync/reinstall; background video is deterministic; Photos + Files import; foundation for alignment tools.

### Starter artifacts (use these first)

| Order | File | Purpose |
|-------|------|---------|
| 1 | [`MIGRATION_USER_RECORDINGS_VIDEO.sql`](MIGRATION_USER_RECORDINGS_VIDEO.sql) | Adds `video_file_path` column |
| 2 | [`SETUP_USER_RECORDING_VIDEOS_BUCKET.sql`](SETUP_USER_RECORDING_VIDEOS_BUCKET.sql) | Bucket `user-recording-videos` + storage policies |
| 3 | [`RPC_LAUNCH_VIDEO_USER_RECORDINGS.sql`](RPC_LAUNCH_VIDEO_USER_RECORDINGS.sql) | `insert_user_recording` + `update_user_recording` with video fields |

**Deploy SQL before** shipping an App Store build that sends `p_video_file_path`.  
**Warning:** `RPC_LAUNCH_VIDEO_USER_RECORDINGS.sql` uses `DROP FUNCTION ... CASCADE` for `insert_user_recording`; confirm no DB objects depended on the old overload.

---

## 1. Problem statement

Today:

- Audio uploads to Supabase; **video stays local** (`VideoAssetStore`). `videoUrl` is patched on the in-memory `AudioTrack` after insert but **never stored in Postgres** or fetched in `SupabaseUserRecording`.
- Soundscape picks background via `first(where: { $0.videoUrl != nil })` among active tracks → **undefined** with multiple video-backed tracks.
- Import is **UIImagePickerController** only → no Files / modern picker UX.

This spec fixes **cloud parity** and **composition semantics**, and adds **import surfaces**. Timeline trimming is **Phase B** (schema reserved).

---

## 2. Goals & non-goals

### Goals (launch)

| ID | Requirement |
|----|-------------|
| G1 | `user_recordings` stores optional **`video_file_path`** (storage object path, same convention style as `file_path`). |
| G2 | Client **uploads video** after successful audio upload (or transactional order defined below). |
| G3 | `fetchUserRecordings` maps `video_file_path` → **`videoUrl`** public URL (same pattern as audio). |
| G4 | **Explicit session background**: user-selected recording id (or “none”) drives `ImmersiveBackground` video, not `first(where:)`. |
| G5 | **PHPicker** (Photos) + **UIDocumentPicker** (Files / iCloud / providers) for video selection; existing camera flow may remain on UIImagePicker if preferred. |
| G6 | Soft-delete / delete recording path **removes or orphans** storage objects consistently (minimum: document behavior; ideal: delete video object in same RPC or app-side after delete). |

### Non-goals (defer)

- Rendering a single exported movie file for share (FFmpeg / AVComposition export).
- Multi-video layers, LUTs, Ken Burns automation.
- Server-side transcoding.

---

## 3. Architecture

```
[Picker] → temp/copy URL → VideoProcessingService.extractAudio → RecordingResult
       → RecordingMetadataView save
              → POST audio → Storage (user-recordings)
              → RPC insert_user_recording (..., p_video_file_path optional)
              → POST video → Storage (user-recording-videos)  [if video chosen]
              → PATCH/RPC if two-phase insert requires updating row with video path after upload
```

**Two-phase option:** If you insist video exists before insert, order is: upload video first → insert with both paths. **Recommended:** insert audio row first with `video_file_path = NULL`, upload video, then **`update_user_recording`** (extended) or lightweight **`PATCH user_recordings`** to set `video_file_path` (RLS must allow). Simplest **launch approach:** extend **`insert_user_recording`** to accept optional `p_video_file_path`; client uploads video **before** RPC and passes path (audio already uploaded too). Order:

1. Upload `{user_id}/{recording_id}.m4a` → `user-recordings`
2. Upload `{user_id}/{recording_id}.{ext}` → `user-recording-videos`
3. RPC `insert_user_recording` with `p_file_path` + **`p_video_file_path`** (nullable if user disables background)

If step 2 fails: row still valid **without** video (match metadata toggle “use video background”).

---

## 4. Database

### 4.1 Column

```sql
ALTER TABLE user_recordings
  ADD COLUMN IF NOT EXISTS video_file_path TEXT NULL;

COMMENT ON COLUMN user_recordings.video_file_path IS
  'Storage path under user-recording-videos bucket, e.g. {user_id}/{recording_id}.mov';
```

Optional Phase B columns (add same migration or follow-up):

```sql
-- Phase B: alignment (nullable = full-length / no offset)
ALTER TABLE user_recordings
  ADD COLUMN IF NOT EXISTS audio_trim_start_seconds DOUBLE PRECISION NULL,
  ADD COLUMN IF NOT EXISTS audio_trim_end_seconds DOUBLE PRECISION NULL,
  ADD COLUMN IF NOT EXISTS video_offset_ms INTEGER NULL;
```

### 4.2 RPC: `insert_user_recording`

**Change:** Add optional parameter **`p_video_file_path text DEFAULT NULL`**.

- Append to `INSERT` column list and `VALUES`.
- Preserve existing validation and `SECURITY DEFINER`.

**Deployment note:** PostgreSQL may retain an old overload. Migration must **`DROP FUNCTION`** all existing `insert_user_recording` signatures (see repo scripts like `DROP_ALL_INSERT_FUNCTIONS.sql`), then create the single canonical function. Coordinate with **SupabaseService** payload keys.

Example signature (names align with existing style):

```sql
CREATE OR REPLACE FUNCTION insert_user_recording(
    p_id uuid,
    p_file_path text,
    p_duration_seconds integer DEFAULT NULL,
    p_name text DEFAULT NULL,
    p_category text DEFAULT NULL,
    p_description text DEFAULT NULL,
    p_icon text DEFAULT NULL,
    p_location_name text DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_longitude double precision DEFAULT NULL,
    p_video_file_path text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
-- INSERT includes video_file_path from p_video_file_path
$$;
```

### 4.3 RPC: `update_user_recording`

Extend to allow clearing or setting video path later (sync repair, user removes background):

- Add optional **`p_video_file_path text`** — use `NULL` passed explicitly vs sentinel; Postgres RPC via JSON often uses omission vs `null`. Document: **omit** = no change; frontend sends `null` only if API supports “set NULL”. Practical approach: add **`p_clear_video boolean DEFAULT false`** OR separate **`patch_user_recording_video`** — pick one to avoid ambiguous NULL.

**Recommendation:** add **`p_video_file_path text DEFAULT NULL`** and **`p_update_video boolean DEFAULT false`**: when `p_update_video` is true, set `video_file_path = p_video_file_path` (including SQL NULL). Swift sends explicit flag only when editing video association.

Phase B: same pattern for trim columns optional params.

### 4.4 Indexes

Optional (low cardinality per user):

```sql
CREATE INDEX IF NOT EXISTS idx_user_recordings_video_path
  ON user_recordings (user_id)
  WHERE video_file_path IS NOT NULL;
```

---

## 5. Storage: bucket `user-recording-videos`

Mirror **`user-recordings`** posture:

- **Private bucket** with RLS policies: users **`INSERT`/`UPDATE`/`DELETE`** only under prefix `{auth.uid()}/**`.
- **Public read** only if the app uses `/object/public/...` today for audio; **match audio bucket**. Current Swift builds playback URL as:

  `{storageURL}/object/public/user-recordings/{file_path}`

  Apply same for videos:

  `{storageURL}/object/public/user-recording-videos/{video_file_path}`

If audio is actually **signed URL** in production, switch **both** to signed URLs in a dedicated hardening task; this spec stays consistent with existing `fetchUserRecordings` audio URL construction.

### Object naming

- Path: `{user_uuid}/{recording_uuid}.{extension}`
- Extension: preserve source (`mov`, `mp4`, `m4v`) or normalize to `mp4` in a later optimization.

### Content-Type on upload

- Set `Content-Type` appropriately (`video/mp4`, `video/quicktime`) from file extension.

---

## 6. iOS client

### 6.1 Models

**`AudioTrack`** (`Models/AudioTrack.swift`)

- Keep **`videoUrl: String?`** as **derived playback URL** (public URL string), not the storage path.
- Add **`videoFilePath: String?`** optional **storage-relative path** if useful for debugging/re-upload; or derive URL only in service layer to avoid duplication. **Recommendation:** single field **`videoUrl`** for playback + **`videoFilePath`** internal optional only if needed for deletes.

Phase B fields on `AudioTrack` (Codable, defaults):

- `audioTrimStartSeconds: Double?`
- `audioTrimEndSeconds: Double?`
- `videoOffsetMilliseconds: Int?`

### 6.2 `SupabaseUserRecording`

Add:

```swift
let video_file_path: String?
// Phase B: let audio_trim_start_seconds: Double? etc.
```

### 6.3 `SupabaseService`

| Method | Change |
|--------|--------|
| `uploadRecording(...)` | After audio upload: if video file present, **`uploadRecordingVideo`** to `user-recording-videos`; include **`p_video_file_path`** in RPC payload. |
| `fetchUserRecordings` | When mapping to `AudioTrack`, if `video_file_path != nil`, set **`videoUrl`** = `\(SupabaseConfig.storageURL)/object/public/user-recording-videos/\(path)` (exact prefix must match bucket visibility). |
| `updateUserRecording` | Wire new params when user toggles background off/on from editor. |

**Delete:** When implementing storage cleanup, call Storage DELETE for `{video_file_path}` when recording soft-deleted or hard-deleted per product decision.

### 6.4 Composition session (G4)

Introduce a small **`CompositionSessionStore`** (Observable / `@AppStorage`):

- **`backgroundRecordingId: UUID?`** — must reference a track present in `audioManager.tracks` **or** be nil.
- When user activates a **video-backed** recording long-press / modal action **“Use as background”**, set this id.
- **`Soundscape3DView.activeVideoURL`**: resolve `audioManager.tracks.first { $0.id == session.backgroundRecordingId }?.videoUrl`, validated **file exists or URL reachable**.

Persist session across launches via **`UserDefaults`** key `composition.backgroundRecordingId` (string uuid).

**Rules:**

- If referenced recording missing (deleted), clear session + fallback no video.
- Master volume / active grid unchanged; background is **visual-only** for v1.

### 6.5 Import UI

| Component | Responsibility |
|-----------|----------------|
| `PhotoLibraryVideoPicker` | `PHPickerViewController`, filter `movie` |
| `DocumentVideoPicker` | `UIDocumentPickerViewController` for `public.movie`, `public.mpeg-4` UTTypes |

**Flow:** `RecordingView` (or sheet) offers **Record | Import from Photos | Import from Files** — wire to same `handleVideoPicked`.

Security-scoped URLs from document picker: **start/stop** access around copy/extract; copy into temp or `VideoAssetStore` before dismissing.

### 6.6 `VideoBackgroundView`

Replace SwiftUI `VideoPlayer` with **`UIViewRepresentable` + `AVPlayerLayer`** (no system chrome). Preserve mute + loop via `AVPlayerLooper`. Parameterize **blur/opacity** optional later.

---

## 7. API contract summary

### Insert RPC JSON (additive)

```json
{
  "p_id": "uuid",
  "p_file_path": "uuid/recording.m4a",
  "p_duration_seconds": 120,
  "p_name": "Title",
  "p_category": "My Recordings",
  "p_description": null,
  "p_icon": "waveform",
  "p_location_name": null,
  "p_latitude": null,
  "p_longitude": null,
  "p_video_file_path": "uuid/recording.mov"
}
```

`p_video_file_path` omitted or null → no video.

---

## 8. Migration & rollout

1. Land **SQL migration** in Supabase (column + bucket + policies + replace RPC).
2. Ship **iOS** that sends new field **only when video uploaded** (backward compatible if RPC default NULL).
3. Old app versions: ignore unknown column (safe); old RPC without param must be **replaced** server-side — deploy SQL **before** App Store binary that sends `p_video_file_path`.
4. Feature-flag optional: none required if server accepts NULL.

---

## 9. Testing checklist

| Case | Expected |
|------|----------|
| New recording, video on | Row has `video_file_path`; fetch shows `videoUrl`; background plays |
| New recording, video off | `video_file_path` null |
| Sign out / delete reinstall | Same user fetch restores video URL |
| Document picker iCloud large file | Extraction completes or actionable error |
| Video without audio track | Existing `VideoProcessingError.noAudioTrack` |
| Session points to deleted recording | Session clears, no crash |
| Two video-backed tracks active | Only **session** background shows |

---

## 10. Implementation tickets (order)

1. **DB:** run [`MIGRATION_USER_RECORDINGS_VIDEO.sql`](MIGRATION_USER_RECORDINGS_VIDEO.sql).
2. **Storage:** run [`SETUP_USER_RECORDING_VIDEOS_BUCKET.sql`](SETUP_USER_RECORDING_VIDEOS_BUCKET.sql).
3. **RPC:** run [`RPC_LAUNCH_VIDEO_USER_RECORDINGS.sql`](RPC_LAUNCH_VIDEO_USER_RECORDINGS.sql) (staging → production).
4. **Swift:** `SupabaseUserRecording`, upload helper, `uploadRecording` orchestration, fetch mapping.
5. **`CompositionSessionStore` + Soundscape wiring** for background resolution.
6. **Pickers:** Photos + Files → existing `handleVideoPicked`.
7. **`VideoBackgroundView`** player layer refactor.
8. **QA:** matrix + TestFlight notes.

**Phase B:** timeline fields + UI sliders + engine honor trim/offset (`AudioManager` / `AudioRenderingEngine`).

---

## 11. Open decisions (resolve before coding)

1. **Bucket public vs signed URLs** — align with current `user-recordings` production behavior.
2. **Delete recording:** remove video object from storage in-app vs Edge Function vs defer.
3. **Max upload size** — enforce client-side before upload; match Supabase limits.

---

## Appendix A: Files likely touched

- `openambi-studio/Services/SupabaseService.swift`
- `openambi-studio/Services/RecordingManager.swift` / `RecordingMetadataView.swift` (upload order)
- `openambi-studio/Soundscape3DView.swift`
- `openambi-studio/Models/AudioTrack.swift`
- `openambi-studio/VideoBackgroundView.swift`
- `openambi-studio/RecordingView.swift`
- New: `CompositionSessionStore.swift`, `PhotoLibraryVideoPicker.swift`, `DocumentVideoPicker.swift`
- [`MIGRATION_USER_RECORDINGS_VIDEO.sql`](MIGRATION_USER_RECORDINGS_VIDEO.sql), [`SETUP_USER_RECORDING_VIDEOS_BUCKET.sql`](SETUP_USER_RECORDING_VIDEOS_BUCKET.sql), [`RPC_LAUNCH_VIDEO_USER_RECORDINGS.sql`](RPC_LAUNCH_VIDEO_USER_RECORDINGS.sql)

---

## Appendix B: Acceptance criteria (launch)

- [ ] Fresh install: user records/import video → saves signed in → **kills app** → reopen → **video background still available** from library fetch.
- [ ] User sets **composition background** explicitly; behavior stable with multiple recordings.
- [ ] Photos + Files import both work on device.
- [ ] No reliance on local-only `file://` URLs for cloud-backed tracks after successful sync.
