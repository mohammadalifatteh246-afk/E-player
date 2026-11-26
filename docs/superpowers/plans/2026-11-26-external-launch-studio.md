# External File Launch, OS Intents & File Association Studio Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable direct playback of external files, URIs, playlists, subtitles, and archives launched from Android `ACTION_VIEW`/`ACTION_SEND` intents and Windows CLI / Explorer "Open With" (both cold-start and warm single-instance), alongside a Cyberpunk OS Launch & Association Studio UI.

**Architecture:**
1. **Native OS Bridges:**
   - **Android:** Add `ACTION_VIEW` & `ACTION_SEND` `<intent-filter>` blocks (`video/*`, `audio/*`, playlists, file/content/network schemes) in `AndroidManifest.xml`. Update `MainActivity.kt` to capture `onCreate` and `onNewIntent`, extract friendly `DISPLAY_NAME`, resolve readable file paths or `fdclose://<fd>` (caching small `.srt`/`.m3u`/`.zip` content URIs safely), and expose MethodChannel `com.example.app/external_launch`.
   - **Windows:** Pass CLI `argv` into `main(List<String> args)`. Upgrade `windows/runner/main.cpp` and `flutter_window.cpp` with Win32 `WM_COPYDATA` single-instance IPC over the same `com.example.app/external_launch` MethodChannel (respecting `--allow-multiple` or `HKCU\Software\E-Player\SingleInstance`).
2. **Domain & Service Layer:**
   - `external_launch_models.dart`: Immutable `ExternalLaunchRequest`, `ExternalMediaKind` classifier, `WarmLaunchBehavior`, and `ExternalLaunchParser` (strips quotes, normalizes `file://` URIs, filters Flutter/Chromium CLI flags, groups sidecar subtitles with primary media).
   - `external_launch_service.dart`: Singleton `ChangeNotifier` coordinating cold-start queued launches, live warm-launch `Stream`, MethodChannel platform calls, SharedPreferences Studio settings, launch history, and Per-User Windows `HKCU\Software\Classes` file association registration (`reg.exe`, no UAC prompt).
3. **Studio UI & Navigation Wiring:**
   - `external_launch_studio_sheet.dart`: Cyberpunk Studio sheet with live Android/Windows diagnostics, one-click Windows Explorer "Open With" registration, single-instance & warm-launch toggles, interactive path/URI simulator, and launch history log.
   - `main.dart`, `player_screen.dart`, `settings_screen.dart`: Update `main(List<String> args)`, attach `GlobalKey<NavigatorState>`, auto-launch `PlayerScreen` on cold-start, route warm launches smoothly into an active `PlayerScreen` (live subtitle attachment, playlist queue, or switch playback), and expose Studio in `SettingsScreen`.

**Tech Stack:** Flutter 3.x+, Dart 3.x, Kotlin (Android `MethodChannel`, `OpenableColumns`, `ParcelFileDescriptor`), C++ Win32 (`WM_COPYDATA`, `flutter::MethodChannel`, `RegGetValueW`), `provider`, `shared_preferences`. Zero third-party native pub plugins added (FAT32 safe).

## Global Constraints
- Pure Dart packages only in `pubspec.yaml` (no new plugins requiring NTFS symlinks).
- Always run Flutter commands with `--no-pub`.
- Keep all existing PlayerScreen/SettingsScreen behavior backward compatible.

## Review Focus
1. **Android Scoped Storage `content://` URIs without `_data`:** `MediaStore._DATA` returns null/unreadable on Android 11+ `FileProvider`; must open `ParcelFileDescriptor` (`fdclose://<fd>`) for media or copy small subtitle/playlist/archive bytes to `cacheDir` with sanitized filename so Dart `File` / `SubtitleTrack` works.
2. **Flutter / Chromium CLI flags in Windows `args`:** `flutter run` or desktop launchers pass `--observatory-port`, `--dart-define`, `--enable-software-rendering`; `ExternalLaunchParser` must ignore any `--*` flag tokens before treating a token as a file path.
3. **Windows `file:///` URI & quoted paths:** Double-quoted `"D:\My Movies\clip.mkv"` or `file:///D:/clip.mkv` must normalize cleanly to `D:\My Movies\clip.mkv` (Windows) without breaking `http://`, `https://`, `rtsp://`, `smb://`, or `fdclose://`.
4. **Cold-start race between OS channel & Flutter first frame:** `MainActivity` or CLI args arrive before `MaterialApp` builds; `ExternalLaunchService` must buffer `pendingColdStartRequest` until consumed cleanly after the first frame without double-playing.
5. **Subtitles dropped/opened externally while already watching a video:** Receiving a `.srt`/`.ass`/`.vtt` externally during warm playback must attach to the active `PlayerScreen` subtitle track without restarting the video, whereas receiving `.mp4`/`.mkv` respects `WarmLaunchBehavior` (`playImmediately` vs `enqueueToPlaylist`).
