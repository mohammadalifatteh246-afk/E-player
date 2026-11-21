# Comprehensive Investigation Report: Hermes Agent Environment, Skill Architecture, Brainstorming Principles, and E-Player Specialized Skills

**Author:** Teamwork Explorer Agent  
**Date:** 2026-11-12  
**Investigation Scope:** Read-Only Analysis of Hermes CLI, MCP Tools, Profiles, Skill Architecture, Brainstorming Directives, Mirroring Topology, and E-Player Technical Requirements  
**Working Directory:** `D:\E-player`  
**State Folder:** `D:\E-player\.agents\teamwork\explorer_m1_hermes_skills`

---

## 1. Executive Summary

This report delivers an empirical analysis of the Hermes agent ecosystem, its skill specification standards, its integration with brainstorming principles, and the multi-path distribution topology across `D:\Agents workespaces` and `D:\overload`. It culminates in concrete, production-grade blueprints for the specialized Hermes agent skills required to drive project **E-Player** (Flutter/Dart desktop player, libmpv multimedia engine, and native C++ neural AI engine) to completion with zero defects.

### Key Discoveries & Architectural Invariants:
1. **Hermes Runtime Topology**: Hermes Agent is deployed at `C:\Users\Admin\AppData\Local\hermes\bin\hermes.exe` and `hermes-acp.exe`. Its configuration and state reside under `C:\Users\Admin\AppData\Local\hermes` (rather than `~/.hermes`), hosting 38 specialized agent profiles (e.g., `coder`, `architect`, `qa`, `verifier`, `overlord`, `decompiler`, `frontend-engineer`).
2. **Skill Architecture**: Hermes loads skills from category-based subfolders under `C:\Users\Admin\AppData\Local\hermes\skills\<category>\<skill-name>\SKILL.md` or profile-scoped skill directories. Each skill is governed by a strict YAML frontmatter (`name`, `description`, `version`, `author`, `license`, `platforms`, `metadata.hermes.tags`) followed by an operational playbook structure.
3. **Brainstorming Synergy**: Hermes skills can directly codify the brainstorming process from `superpowers:brainstorming` (Intent Discovery -> Exploring Alternative Approaches with Tradeoffs -> Written Design Documentation -> Builder Check Verification -> Hard Gates before Implementation).
4. **Mirroring Guardrails**: Multi-path distribution requires rigorous SHA256 cryptographic parity across `D:\Agents workespaces` (including its 8 functional sectors) and `D:\overload`, adhering strictly to storage drive isolation rules.
5. **E-Player Skill Blueprint**: Four specialized Hermes skills are defined to execute E-Player tasks cleanly:
   - `eplayer-flutter-video-arch` (Flutter/Dart Video Architecture & Player Lifecycle Ops)
   - `eplayer-mpv-vlc-parity` (libmpv Core Control & VLC Gap Parity Engine)
   - `eplayer-native-neural-ffi` (C++ Native Neural Engine FFI Operations)
   - `eplayer-verification-guardrail` (Quality Assurance, Static Analysis & Multi-Path Mirroring)

---

## 2. Hermes Agent Environment & CLI Architecture

### 2.1 Binaries and Path Verification
Forensic verification of the system PATH and local binaries identified the following Hermes executables:
- **`hermes.exe`**: `C:\Users\Admin\AppData\Local\hermes\bin\hermes.exe`
- **`hermes-acp.exe`**: `C:\Users\Admin\AppData\Local\hermes\bin\hermes-acp.exe` (Agent Client Protocol server bridge)

### 2.2 System Directory Structure & Home Resolution
On this Windows host, Hermes resolves its home directory to `C:\Users\Admin\AppData\Local\hermes`:
```
C:\Users\Admin\AppData\Local\hermes\
├── bin/                       # Executables (hermes.exe, hermes-acp.exe)
├── config.yaml                # Master configuration file (providers, models, tools)
├── SOUL.md                    # Core agent persona definition
├── state.db                   # SQLite state database (WAL mode)
├── profiles/                  # Isolated sub-agent profiles (38 bots)
├── skills/                    # Global skill store (organized by category)
├── plugins/                   # Dynamic plugins and extensions
├── sessions/                  # Conversation history and transcripts
├── cron/                      # Background task scheduler jobs
└── gateway-service/           # Messaging gateway daemon
```

### 2.3 Profile Architecture (The 38-Bot Enterprise Ecosystem)
Hermes incorporates an enterprise multi-agent profile model. Under `C:\Users\Admin\AppData\Local\hermes\profiles\`, 38 distinct agent profiles are registered:
- **Architecture & Coordination**: `overlord`, `architect`, `full-stack-architect`, `supervisor-alpha` through `supervisor-zeta`, `git-nexus`
- **Engineering & Implementation**: `coder`, `frontend-engineer`, `backend-engineer`, `patch-engineer`, `game-programmer`, `game-architect`
- **Quality & Verification**: `qa`, `verifier`, `reviewer`, `regression-tester`, `reproducer`, `root-cause`, `playtester`
- **Reverse-Engineering & Systems**: `decompiler`, `disassembler`, `forensic`, `instrumenter`
- **Research & UX**: `deep-research-master`, `ux-researcher`, `ui-designer`, `svg-animator`, `writer`, `synthesizer`, `a11y-auditor`, `scout`

Each profile directory contains its own isolated runtime environment:
- `config.yaml`: Profile-specific model endpoint, context length, and MCP server configuration.
- `skills/`: Dedicated profile skills directory (mirroring or overriding global skills).
- `SOUL.md`: Role-specific mission and behavior directives (e.g. `coder` mandates clean-room code with zero TODOs/placeholders).
- `state.db`: Local memory, sessions, and telemetry database.

### 2.4 Antigravity MCP Integration Bridge
Hermes connects to Google Antigravity and external messaging platforms via the Hermes MCP server at `C:\Users\Admin\.gemini\antigravity\mcp\hermes`. The server registers 11 tools:
- `messages_send`: Sends messages across Telegram, Discord, Slack, WhatsApp, Signal, Matrix (`platform:target`).
- `messages_read`: Retrieves recent conversation logs.
- `conversations_list`: Enumerates active communication channels.
- `conversation_get`: Fetches conversation metadata and message streams.
- `events_poll` & `events_wait`: Long-polling and event-driven wakeups for autonomous workflows.
- `channels_list`: Resolves human-readable channel handles to platform targets.
- `permissions_list_open` & `permissions_respond`: Security authorization negotiation.
- `attachments_fetch`: Downloads shared file payloads.

Additionally, profile configuration files (`config.yaml`) establish outbound MCP connections to:
- `StitchMCP`: `https://stitch.googleapis.com/mcp` (UI/UX screen design and generation)
- `crosswalk`: `https://mcp.crosswalk.to` (24/7 cloud runner and task coordination)

### 2.5 Hermes CLI Command Surface
Execution of `hermes --help` and `hermes skills --help` revealed the complete operational command matrix:
- **Interactive Chat**: `hermes` (starts modern TUI via `--tui` or classic REPL via `--cli`).
- **Profile Targeting**: `hermes -p <profile> <command>` (e.g., `hermes -p coder chat`).
- **One-Shot Autonomous Execution**: `hermes chat --yolo --oneshot -Q -z "<prompt>"` or `--query-file <PATH>`:
  - `--yolo`: Bypasses confirmation prompts for automated file system and tool operations.
  - `--oneshot` / `-z`: Executes a single turn and outputs raw final response text.
  - `--usage-file PATH`: Outputs structured JSON telemetry on tokens and API calls.
  - `--max-turns <N>`: Guards against runaway reasoning loops.
- **Skill Management**:
  - `hermes skills list`: Lists all 62 enabled skills across `hub-installed`, `builtin`, and `local`.
  - `hermes skills trust`: Authorizes a project workspace so `./.hermes/skills` or `./.agents/skills` load automatically.
  - `hermes skills install <target>`: Fetches and installs skills from registries.
  - `hermes skills inspect <name>`: Previews a skill definition without installing.

---

## 3. Hermes Skill Architecture & Schema Standards

### 3.1 Directory Layout & Resolution Hierarchy
Hermes searches for skills in three prioritized locations:
1. **Global Skills**: `C:\Users\Admin\AppData\Local\hermes\skills\<category>\<skill-name>\SKILL.md` (e.g. `daily-spark-intel\mirror-sync-guardrail\SKILL.md`) or `C:\Users\Admin\AppData\Local\hermes\skills\<skill-name>\SKILL.md`.
2. **Profile Skills**: `C:\Users\Admin\AppData\Local\hermes\profiles\<profile>\skills\<category>\<skill-name>\SKILL.md`.
3. **Workspace Skills**: `<project_root>/.hermes/skills/<skill-name>/SKILL.md` or `<project_root>/.agents/skills/<skill-name>/SKILL.md` (after `hermes skills trust`).

### 3.2 Skill Catalog Audit
Executing `hermes skills list` confirmed **62 active skills**:
- **4 Hub-Installed**: `ethos-explore`, `memory-never-forget`, etc.
- **43 Builtin**: `sdlc-review`, `codebase-inspection`, `systematic-debugging`, `test-driven-development`, `claude-design`, etc.
- **15 Local**: `brainstorming`, `scroll-experience`, `mirror-sync-guardrail`, `antigravity-engine-ops`, `spark-bridge`, `daily-spark-intel`, `hermes-overlord`, `multi-agent-coding-team`, `ui-ux-design-team`, etc.

### 3.3 Exact YAML Frontmatter Specification
Auditing `antigravity-engine-ops`, `mirror-sync-guardrail`, `spark-bridge`, and `daily-spark-intel` establishes the standard YAML frontmatter contract:
```yaml
---
name: <kebab-case-identifier>
description: "<Imperative summary sentence under 120 chars>"
version: "1.0.0"
author: "Hermes Agent"
license: "MIT"
platforms: ["windows", "linux", "macos"]
metadata:
  hermes:
    tags: ["tag-1", "tag-2", "tag-3"]
---
```

### 3.4 Operational Skill Markdown Body Structure
Every production Hermes skill follows a battle-tested 6-section structure:
1. **`# <Skill Title>`**: Clear declarative header matching `name`.
2. **`## When to Use`**: 4–6 bulleted conditions and trigger symptoms.
3. **`## Quick Reference Table`**: A 3-column table (`Target | Action / Tool Command | Expected Outcome`) mapping tasks to exact shell commands or tool calls.
4. **`## Core Subsystems & Technical Specifications`**: Deep engineering foundations, mathematical formulas (e.g., PID formulas, volume gain coefficients, seek intervals), architecture diagrams, and property invariants.
5. **`## Operational Workflows`**: Step-by-step procedures with numbered instructions and copy-pasteable bash/PowerShell snippets.
6. **`## Common Mistakes & Prohibitions`**: Negative constraints, prohibited flags, and anti-patterns that lead to regressions or build failures.

---

## 4. Brainstorming Principles in Hermes Skill Authoring

### 4.1 Deconstruction of `superpowers:brainstorming`
Analysis of `C:\Users\Admin\.gemini\config\plugins\superpowers\skills\brainstorming\SKILL.md` reveals five non-negotiable phases:
1. **Intent Discovery ("Look Before You Ask")**: Never guess or implement prematurely. Examine existing code, architecture documents, and user constraints before asking questions. Formulate precise Socratic questions that clarify intent, scope boundaries, and non-goals.
2. **Exploring Alternative Approaches with Tradeoffs**: Formulate 2 to 3 genuine, viable architectural alternatives. Explicitly analyze pros, cons, complexity, performance impact, and long-term maintenance costs for each approach. Recommend the optimal path with evidence-backed justification.
3. **Structured Design Documentation**: Document the agreed architecture before writing production code:
   - Problem statement & core intent
   - Goals, non-goals, and anti-goals
   - Architectural alternatives & trade-off rationale
   - Interface contracts, data models, and component boundaries
   - Verification strategy
4. **Builder Check & Self-Review**: Validate the design against practical implementation constraints:
   - Identify ambiguities or unhandled edge cases
   - Partition issues into "Already Answered", "Minor Builder Calls", and "User Decisions"
5. **Hard Gate Enforcement**: No production code, scaffolding, or dependency additions may occur until the design document is explicitly validated and approved.

### 4.2 Encoding Brainstorming Principles into Hermes Skills
Specialized Hermes skills must encode these principles directly into their operational workflows:
- **Mandatory Pre-Implementation Check**: Skills must instruct the agent to inspect existing contracts and models before suggesting modifications.
- **Alternative Formulation Step**: When presenting architectural choices (e.g. choosing between libmpv `vf` crop filter vs. Flutter `FittedBox` clipping; choosing between `audio-delay` property vs. WebAudio graph DSP), the skill mandates presenting the alternative with tradeoffs.
- **Self-Review Checklist**: Skills must include a pre-completion checklist that verifies zero placeholders, zero TODOs, strict typing, and clean static analysis.

---

## 5. Distribution & Mirroring Topology

### 5.1 System Drives & Storage Isolation Guardrail
Per `mirror-sync-guardrail`:
- **System Drive (`C:\`) Protection**: Heavy build artifacts, cached dependencies, and redundant workspace mirrors must not be placed on the OS partition.
- **Project & Mirror Drive (`D:\`)**: Development workspaces, sector folders, and persistent mirror archives reside exclusively on Drive `D:`.

### 5.2 Target Directory Hierarchy
```
D:\
├── E-player\                                    # Primary Workspace Root
│   ├── app\                                     # Flutter mobile/desktop codebase
│   ├── native\                                  # C++ neural AI engine (eplayer_engine)
│   ├── docs\                                    # VLC gap analysis & architecture specs
│   └── .agents\teamwork\                        # Teamwork coordination metadata
├── Agents workespaces\                          # Mirror Destination 1
│   ├── Core Coding & Architecture Sector\       # Sector 1: Core engineering
│   ├── UIUX Design & Visuals Sector\            # Sector 2: Design & UI components
│   ├── Research & Synthesis Sector\             # Sector 3: Technical research & gap analysis
│   ├── QA, Testing & Verification Sector\       # Sector 4: Test suites & quality gates
│   ├── DevOps & Infrastructure Sector\          # Sector 5: Build pipelines & CI
│   ├── Security, Forensics & Patching Sector\   # Sector 6: Binary audits & vault security
│   ├── Game Dev & Binary Engineering Sector\    # Sector 7: C++ FFI & native libraries
│   ├── Overlord Command Council\                # Sector 8: Governance & multi-agent routing
│   ├── skills\                                  # Mirrored Hermes skills repository
│   └── daily-spark-intel\                       # Mirrored daily briefings & reports
└── overload\                                    # Mirror Destination 2
    ├── skills\                                  # Mirrored Hermes skills repository
    ├── daily-spark-intel\                       # Mirrored daily briefings & reports
    ├── AGENTIC_COMPANY_CHARTER.md               # Enterprise governance charter
    └── all_39_bots_enterprise_blueprint.pdf     # Profile taxonomy specification
```

### 5.3 Cryptographic SHA256 Parity Verification Protocol
Synchronization is complete **only** when cryptographic hash parity is established across all three paths:
$$\text{SHA256}(P_{\text{primary}}) == \text{SHA256}(P_{\text{mirror1}}) == \text{SHA256}(P_{\text{mirror2}})$$

The verification routine:
```python
import hashlib
from pathlib import Path

def verify_parity(p1: Path, p2: Path, p3: Path) -> bool:
    def h(p):
        hasher = hashlib.sha256()
        with open(p, "rb") as f:
            while chunk := f.read(65536):
                hasher.update(chunk)
        return hasher.hexdigest()
    h1, h2, h3 = h(p1), h(p2), h(p3)
    assert h1 == h2 == h3, f"Parity mismatch: {h1} vs {h2} vs {h3}"
    return True
```

---

## 6. Recommended Specialized Hermes Agent Skills for E-Player

Based on the VLC reverse-engineering findings (`docs/vlc_gap_analysis.md`), the Flutter codebase architecture (`PROJECT.md`, `app/lib/`), and the C++ neural engine (`native/engine/include/eplayer_engine.h`), four specialized Hermes skills are recommended.

### Skill 1: `eplayer-flutter-video-arch`
- **Identifier**: `eplayer-flutter-video-arch`
- **Category**: `software-development` / `eplayer`
- **Mission**: Guide the agent through Flutter Desktop/Mobile architecture, reactive state flow via `Provider`, gesture physics, and glassmorphic UI components.
- **Frontmatter**:
```yaml
---
name: eplayer-flutter-video-arch
description: "Orchestrate Flutter video player architecture, gesture physics, HUD controls, and reactive UI components."
version: "1.0.0"
author: "Hermes Agent"
license: "MIT"
platforms: ["windows", "linux", "macos", "android", "ios"]
metadata:
  hermes:
    tags: ["eplayer", "flutter", "dart", "media-kit", "ui-architecture", "gestures"]
---
```
- **Scope & Capabilities**:
  - `PlayerScreen` lifecycle and HUD overlay mechanics (`features/player/ui/player_screen.dart`).
  - `CinematicGestureEngine` smooth vertical swipe physics scaled across 0% to 300% volume with $K=150.0$ gain and 3-color safety indicator (Green `#22C55E`, Amber `#F59E0B`, Soft Red `#EF4444`).
  - `DesktopKeyboardHandler` universal keyboard navigation (Space, F11, m, b, v, a, c, e, h/g, k/j, +/-, [/], =, Arrow keys, and 4-tier modifier jump physics).
  - Modal glassmorphic bottom sheets: `AudioStudioSheet` (EQ presets, preamp gain, audio sync slider), `VideoEffectsSheet` (color adjust, rotate, deinterlace, crop), `SubtitleSettingsSheet`.
  - Provider state architecture: `SettingsProvider`, `LibraryProvider`, `MediaGroupService`.

### Skill 2: `eplayer-mpv-vlc-parity`
- **Identifier**: `eplayer-mpv-vlc-parity`
- **Category**: `software-development` / `eplayer`
- **Mission**: Manage libmpv property bindings, FFmpeg filter graphs, and VLC playback parity features within `media_kit`.
- **Frontmatter**:
```yaml
---
name: eplayer-mpv-vlc-parity
description: "Control libmpv properties, filter graphs, and audio/video playback parity features via media_kit."
version: "1.0.0"
author: "Hermes Agent"
license: "MIT"
platforms: ["windows", "linux", "macos"]
metadata:
  hermes:
    tags: ["eplayer", "mpv", "vlc-parity", "media-kit", "filter-graphs", "playback-core"]
---
```
- **Scope & Capabilities**:
  - `volume-max: 300.0` configuration and soft-clipping safety guards.
  - Frame-by-frame stepping via libmpv `frame-step` command (auto-pauses on active playback).
  - 4-state A-B repeat looper (`off` -> `pointA` -> `looping` -> `clear`) with anti-thrashing debounce guards.
  - Non-distorted centered crop aspect ratio cycling (`16:9`, `16:10`, `4:3`, `1.85:1`, `2.35:1`, `Reset`) using mpv `vf` crop filter strings.
  - Network buffer caching (`cache-secs: 0.5..10.0s`) and demuxer memory limits (`demuxer-max-bytes: 16..128MB`).
  - Audio delay (`audio-delay: -10.0s..+10.0s` in 50ms nudges) and 10-band equalizer parity (11 VLC presets + `-20dB..+20dB` preamp slider).

### Skill 3: `eplayer-native-neural-ffi`
- **Identifier**: `eplayer-native-neural-ffi`
- **Category**: `software-development` / `eplayer`
- **Mission**: Manage native C++ neural engine operations, Dart FFI bindings, CMake builds, memory pools, and inference pipelines.
- **Frontmatter**:
```yaml
---
name: eplayer-native-neural-ffi
description: "Operate C++ neural AI engine, Dart FFI bindings, tiled super-resolution, RIFE interpolation, and CMake builds."
version: "1.0.0"
author: "Hermes Agent"
license: "MIT"
platforms: ["windows", "linux", "macos", "android", "ios"]
metadata:
  hermes:
    tags: ["eplayer", "cpp", "ffi", "neural-engine", "rife", "real-esrgan", "cmake"]
---
```
- **Scope & Capabilities**:
  - Direct C ABI bindings to `eplayer_engine.dll` (`include/eplayer_engine.h`).
  - Zero-allocation memory pool management (`eplayer_frame_acquire`, `eplayer_frame_release`, `eplayer_frame_get_data`).
  - Tiled spatial super-resolution inference (`eplayer_frame_submit_tiled`) with overlap blending for Real-ESRGAN, Anime4K, and FSRCNN.
  - Temporal frame interpolation via RIFE 60 FPS (`eplayer_set_rife_config`) and buffer flushing on seek (`eplayer_queue_invalidate`).
  - Audio AI speech denoising via RNNoise (`eplayer_set_audio_ai_config`) and automatic subtitle generation (`eplayer_generate_subtitles`).
  - Thermal and hardware capability gating (`eplayer_can_enable_pipeline`).

### Skill 4: `eplayer-verification-guardrail`
- **Identifier**: `eplayer-verification-guardrail`
- **Category**: `guardrails` / `eplayer`
- **Mission**: Enforce clean-room development standards, zero-TODO constraints, automated test suites, static analysis, and multi-path SHA256 mirror synchronization.
- **Frontmatter**:
```yaml
---
name: eplayer-verification-guardrail
description: "Enforce zero-defect code hygiene, static analysis, automated test verification, and multi-path mirror parity."
version: "1.0.0"
author: "Hermes Agent"
license: "MIT"
platforms: ["windows", "linux", "macos"]
metadata:
  hermes:
    tags: ["eplayer", "verification", "static-analysis", "unit-tests", "mirroring", "sha256"]
---
```
- **Scope & Capabilities**:
  - Zero placeholder and zero TODO verification (`dart analyze` / `flutter analyze` with 0 warnings, 0 errors).
  - Automated test execution: unit tests (`flutter test test/unit/phase2_unit_test.dart`) and 4-tier opaque-box E2E suites (`flutter test test/e2e/phase2_e2e_test.dart`).
  - Multi-path mirroring automation copying all deliverables to `D:\Agents workespaces` and `D:\overload`.
  - Automated SHA256 parity verification across source and all mirror locations.

---

## 7. Hermes Configuration & Deployment Guide

To configure Hermes with these specialized skills:

### Step 1: Install Skills into Hermes System Store
Deploy skill folders to:
`C:\Users\Admin\AppData\Local\hermes\skills\eplayer\<skill-name>\SKILL.md`

### Step 2: Seed Skills into Key Profiles
Copy or symlink skill folders into active profile stores, specifically:
- `C:\Users\Admin\AppData\Local\hermes\profiles\coder\skills\`
- `C:\Users\Admin\AppData\Local\hermes\profiles\architect\skills\`
- `C:\Users\Admin\AppData\Local\hermes\profiles\qa\skills\`
- `C:\Users\Admin\AppData\Local\hermes\profiles\verifier\skills\`

### Step 3: Register Workspace Trust
Execute workspace trust from the E-Player repository root:
```powershell
Set-Location -Path "D:\E-player"
hermes skills trust
```

### Step 4: Verify Skill Discovery
Run `hermes skills list` to verify all four `eplayer-*` skills appear with `enabled` status under category `eplayer`.

### Step 5: Execute Autonomous Tasks via Coder Profile
Invoke Hermes in unattended mode with the specialized skills preloaded:
```powershell
hermes -p coder chat --yolo --oneshot -Q -s eplayer-flutter-video-arch,eplayer-mpv-vlc-parity,eplayer-native-neural-ffi,eplayer-verification-guardrail --query-file "D:\E-player\.agents\teamwork\task_prompt.txt"
```

---

## 8. Summary & Next Steps

This investigation provides the complete structural blueprint for Hermes skill development in project E-Player. The four proposed skills directly encapsulate E-Player's Flutter architecture, libmpv player core, native neural FFI engine, and rigorous quality/mirroring guardrails.

The subsequent phase involves generating the actual `SKILL.md` files for these four skills, placing them in `D:\E-player\.agents\skills\`, copying them to `C:\Users\Admin\AppData\Local\hermes\skills\eplayer\`, mirroring them to `D:\Agents workespaces\skills\` and `D:\overload\skills\`, and validating SHA256 parity.
