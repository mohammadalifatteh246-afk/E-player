# BRIEFING — 2026-11-03T09:51:30Z

## Mission
Perform live forensic inspection and clean-room reverse engineering deconstruction of VLC's File Browser, Auto-rescan, and Media Library / Media Library Folders from local installation (C:\Program Files (x86)\VideoLAN\VLC) and user profiles (%APPDATA%\vlc, %LOCALAPPDATA%\vlc).

## 🔒 My Identity
- Archetype: explorer
- Roles: reverse engineering, forensic inspection, architectural deconstruction
- Working directory: d:\E-player\.agents\teamwork\explorer_vlc_local
- Original parent: b2008e01-408f-4008-b628-3252f17ed10a
- Milestone: Stage 1 Forensic Evidence Extraction

## 🔒 Key Constraints
- Read-only investigation — do NOT implement
- Do NOT modify source code or binaries
- All findings structured as Exhibit A (Data & State), Exhibit B (Lifecycle & Algorithms), Exhibit C (Performance & UX)
- Explicitly label every exhibit as [Verified via MCP/Source Inspection] or [Inferred via Behavioral/Architectural Pattern]

## Current Parent
- Conversation ID: b2008e01-408f-4008-b628-3252f17ed10a
- Updated: 2026-11-03T09:42:24Z

## Investigation State
- **Explored paths**:
  - `C:\Program Files (x86)\VideoLAN\VLC` (vlc.exe, libvlc.dll, libvlccore.dll, plugins)
  - `plugins/gui/libqt_plugin.dll`, `plugins/access/libfilesystem_plugin.dll`
  - `plugins/services_discovery/libmediadirs_plugin.dll`, `libwindrive_plugin.dll`
  - `%APPDATA%\vlc` (`ml.xspf`, `vlcrc`, `vlc-qt-interface.ini`, `art/`)
- **Key findings**:
  - Local VLC build is 3.0.24 (32-bit PE).
  - Media Library in VLC 3.0.x is persisted as an XSPF XML tree in `%APPDATA%\vlc\ml.xspf`. SQLite is not compiled into VLC 3.0.x (it was introduced in VLC 4.0's `libmedialibrary`).
  - Directory traversal is executed via `libfilesystem_plugin.dll` (`vlc_opendir`, `_wfindfirst`, `_wfindnext`, `vlc_readdir_helper_additem`, `vlc_readdir_helper_finish`).
  - Subdirectory behavior is controlled via `recursive` (`collapse`, `expand`, `none`) with filtering via `ignore-filetypes` and `show-hiddenfiles`.
  - Directory change monitoring uses Windows API `FindFirstChangeNotificationW` / `FindNextChangeNotification` inside `QWindowsFileSystemWatcherEngineThread`.
  - Album art cache uses dual indexing: URI MD5 hash (`art/arturl/<md5>/art.jpg`) and artist/album metadata (`art/artistalbum/<artist>/<album>/art`).
- **Unexplored areas**: None. Live forensic inspection is complete.

## Key Decisions Made
- Deconstruct both VLC 3.0.x empirical architecture (installed) and VLC 4.0 libmedialibrary architecture (SQLite specification required for E-Player SQLite implementation).
- Provide exhaustive Exhibit A, Exhibit B, Exhibit C with explicit verification labels.

## Artifact Index
- DISPATCH.md — Dispatch log
- BRIEFING.md — Working memory
- progress.md — Liveness heartbeat
- handoff.md — Comprehensive forensic report
