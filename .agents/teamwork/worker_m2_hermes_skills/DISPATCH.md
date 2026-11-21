## 2026-11-12T08:58:24Z
[Message] timestamp=2026-11-12T08:58:24Z sender=21c13783-ab88-4572-9d57-807956b46fec priority=MESSAGE_PRIORITY_HIGH content=You are a teamwork_worker.
Working directory: D:\E-player
State folder: D:\E-player\.agents\teamwork\worker_m2_hermes_skills

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

MANDATORY FIRST STEP: You MUST read ORIGINAL_REQUEST.md before starting work:
Path: D:\E-player\.agents\teamwork\ORIGINAL_REQUEST.md

Context & Reference Materials:
- Milestone 1 Comprehensive Synthesis: D:\E-player\.agents\teamwork\orchestrator_6\ANALYSIS_SYNTHESIS.md
- Hermes Ecosystem Survey: D:\E-player\.agents\teamwork\explorer_m1_hermes_skills\report.md
- Architecture & VLC Gap Report: D:\E-player\.agents\teamwork\spec_miner_m1_architecture_gap\report.md
- Brain & Transcripts Survey: D:\E-player\.agents\teamwork\explorer_m1_survey_brain\report.md
- Brainstorming Skill: C:\Users\Admin\.gemini\config\plugins\superpowers\skills\brainstorming\SKILL.md
- Existing Hermes Skills:
  - D:\Agents workespaces\skills\mirror-sync-guardrail\SKILL.md
  - D:\Agents workespaces\skills\antigravity-engine-ops\SKILL.md
  - D:\Agents workespaces\skills\spark-bridge\SKILL.md
  - D:\Agents workespaces\skills\daily-spark-intel\SKILL.md

Objectives:
1. Design and produce four specialized Hermes agent skills adhering strictly to brainstorming principles in `D:\E-player\skills/`:
   - Skill 1: `D:\E-player\skills\eplayer-flutter-video-arch\SKILL.md` (Flutter 3.13.4, media_kit, PlayerScreen lifecycle, CinematicGestureEngine, DesktopKeyboardHandler, HUD controls, Provider reactive state).
   - Skill 2: `D:\E-player\skills\eplayer-mpv-vlc-parity\SKILL.md` (libmpv engine properties, volume over-amplification across 0% to 300% with 3-color safety indicator, single-frame stepping 'e', 4-state A-B repeat looper, aspect crop cycling 'c' via mpv vf filter, buffer caching settings, audio delay sync slider, 10-band EQ parity with 20 presets and preamp).
   - Skill 3: `D:\E-player\skills\eplayer-native-neural-ffi\SKILL.md` (C++17 native engine in D:\E-player\native\engine, CMake targets, bounded memory pools with kMaxQueueDepth=8 to prevent VRAM exhaustion, tiled Real-ESRGAN x4 super-resolution with Laplacian detail kernels, RIFE 60fps bidirectional frame interpolation with seek invalidation, and typed Dart FFI bindings in lib/core/ffi/engine_bindings.dart).
   - Skill 4: `D:\E-player\skills\eplayer-verification-guardrail\SKILL.md` (Quality assurance, static analysis with flutter analyze, automated test suites in test/unit/ and test/e2e/, zero-placeholder verification, multi-path mirroring to D:\Agents workespaces and D:\overload, cryptographic SHA256 parity verification).

Skill Authoring Invariants:
- Valid YAML frontmatter:
  ```yaml
  ---
  name: <kebab-name>
  description: "<concise purpose>"
  version: "1.0.0"
  author: "Hermes Agent"
  license: "MIT"
  platforms: ["windows", "linux", "macos"]
  metadata:
    hermes:
      tags: [...]
  ---
  ```
- Standard 6-section structure:
  - `# <Title>`
  - `## When to Use`
  - `## Quick Reference Table` (Target | Action / Tool Command | Expected Outcome)
  - `## Core Subsystems & Technical Specifications`
  - `## Operational Workflows`
  - `## Common Mistakes & Prohibitions`
- Brainstorming Integration: Each skill MUST explicitly embed brainstorming principles (Intent discovery, exploring 2-3 approaches with tradeoffs, written design doc, builder check, hard gates before code modification).

2. Deploy & Configure in Hermes Runtime:
   - Install all 4 newly created skills into `C:\Users\Admin\AppData\Local\hermes\skills\`:
     - `C:\Users\Admin\AppData\Local\hermes\skills\eplayer-flutter-video-arch\SKILL.md`
     - `C:\Users\Admin\AppData\Local\hermes\skills\eplayer-mpv-vlc-parity\SKILL.md`
     - `C:\Users\Admin\AppData\Local\hermes\skills\eplayer-native-neural-ffi\SKILL.md`
     - `C:\Users\Admin\AppData\Local\hermes\skills\eplayer-verification-guardrail\SKILL.md`
   - Run `hermes skills list` via CLI or verify skill discovery.

3. Author comprehensive handoff report:
   - Write self-contained handoff to `D:\E-player\.agents\teamwork\worker_m2_hermes_skills\handoff.md`.
   - Message parent with summary.
