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

# E-Player Quality Assurance, Verification & Multi-Path Mirroring Guardrail

## When to Use
- Running quality assurance audits and static code analysis on the E-Player codebase (`D:\E-player\app`).
- Executing automated unit and end-to-end integration test suites via `flutter test`.
- Auditing codebase files for prohibited placeholders, `TODO` comments, fake mocks, or unimplemented stubs.
- Synchronizing project deliverables, documentation, and Hermes skills across external mirrors (`D:\Agents workespaces` and `D:\overload`).
- Calculating and verifying cryptographic SHA256 file parity across primary and mirror destinations.
- Executing unattended Hermes CLI operations in non-interactive mode without terminal hangs.

## Quick Reference Table

| Target / Task | Tool / Command | Expected Outcome |
| :--- | :--- | :--- |
| Static Code Analysis | `flutter analyze` in `D:\E-player\app` | Zero errors, zero warnings across all project files |
| Unit Test Suite | `flutter test test/unit/` | 100% test pass rate across unit tests |
| E2E Integration Suite | `flutter test test/e2e/` | All full-flow integration scenarios pass cleanly |
| Placeholder Scan | PowerShell `Select-String -Pattern "TODO\|FIXME"` | Zero matches in production code |
| Multi-Path Mirroring | Python / PowerShell mirror sync script | Copies all artifacts to `D:\Agents workespaces` and `D:\overload` |
| SHA256 Parity Check | Python `hashlib.sha256` digest audit | Cryptographic parity verified across all destinations |
| Non-Interactive Hermes | `hermes chat --yolo --oneshot -Q --query-file ...` | Autonomous execution without interactive prompt blockage |

## Core Subsystems & Technical Specifications

### 1. Clean-Room Zero-Defect Code Hygiene
E-Player strictly prohibits placeholder implementations, dummy facades, and incomplete stubs:
- **Zero TODO / FIXME Invariant**: No production source file in `lib/` or `native/` may contain `TODO`, `FIXME`, `TBD`, or temporary workarounds.
- **No Unimplemented Methods**: Code must never invoke `throw UnimplementedError()` or return hardcoded dummy literals in place of real logic.
- **Strict Typing**: All Dart code must employ strict typing with explicit generic parameters. Prohibit untyped `dynamic` variables where concrete types are known.

### 2. Static Analysis & Lint Gates
- **Engine**: The official Dart analyzer configured via `analysis_options.yaml`.
- **Execution Command**:
  ```powershell
  Set-Location -Path "D:\E-player\app"
  flutter analyze
  ```
- **Acceptance Threshold**: Zero errors and zero warnings. Any warning is treated as a blocking build failure.

### 3. Automated Testing Harnesses
The test harness is divided into two rigorous tiers:
- **Unit Tests (`test/unit/`)**:
  - `phase1_shortcuts_test.dart`: Validates universal keyboard shortcuts, modifier seek intervals, and audio sync nudges.
  - `phase2_unit_test.dart`: Validates volume scaling across $0\%..300\%$, $K=150.0$ gain constant, frame stepping pause logic, 4-state A-B looper transitions, and aspect crop calculations.
- **End-to-End Integration Tests (`test/e2e/`)**:
  - `phase2_e2e_test.dart`: Comprehensive 4-tier opaque-box test exercising real-time player events, gesture emulation, keyboard dispatch, and UI overlay synchronization.
- **Execution Command**:
  ```powershell
  flutter test --reporter expanded
  ```

### 4. Multi-Path Mirroring Topology & Drive Isolation
To guarantee disaster recovery and enterprise redundancy, project deliverables must be mirrored across designated external drives while preserving OS drive isolation:
- **Primary Development Root**: `D:\E-player\`
- **Mirror Destination 1**: `D:\Agents workespaces\`
  - `Core Coding & Architecture Sector/` $\rightarrow$ Core Dart/C++ architectures and reports.
  - `UIUX Design & Visuals Sector/` $\rightarrow$ Design assets and UI prototypes.
  - `Research & Synthesis Sector/` $\rightarrow$ Gap analysis and technical synthesis.
  - `QA, Testing & Verification Sector/` $\rightarrow$ Test reports and audit ledgers.
  - `skills/` $\rightarrow$ Mirrored Hermes agent skills.
  - `daily-spark-intel/` $\rightarrow$ Architectural briefs and status reports.
- **Mirror Destination 2**: `D:\overload\`
  - `skills/` $\rightarrow$ Mirrored Hermes agent skills.
  - `daily-spark-intel/` $\rightarrow$ Secondary archive of briefings and status reports.

### 5. Cryptographic SHA256 Parity Verification Protocol
Mirroring is incomplete until every destination file is verified to have an identical cryptographic SHA256 digest:
$$\text{SHA256}(P_{\text{primary}}) == \text{SHA256}(P_{\text{mirror1}}) == \text{SHA256}(P_{\text{mirror2}})$$

If even a single byte differs (e.g. line ending translation `CRLF` vs `LF`), the verification fails immediately and must be remediated.

### 6. Non-Interactive Unattended Hermes Execution Protocol
When dispatching Hermes CLI in autonomous or pipeline workflows, the agent must be configured for unattended execution:
- `--yolo`: Automatically approves file modifications and tool calls.
- `--oneshot` / `-z`: Performs a single turn and outputs raw response without launching an interactive TUI.
- `-Q`: Suppresses verbose headers and ASCII art.
- `--query-file <PATH>`: Reads prompt text from an external file to prevent shell quoting errors on Windows PowerShell.
- `--max-turns <N>`: Sets an upper bound on reasoning loops (default $50$ to $100$).

## Operational Workflows

### Workflow 1: Brainstorming Pre-Flight Gate for Verification Protocols
Before altering test harnesses, lint rules, or verification scripts:

1. **Intent Discovery ("Look Before You Ask")**:
   - Inspect existing tests in `app/test/` and CI scripts.
   - Clarify whether the change alters test assertions, introduces new regression boundaries, or modifies external mirror paths.
2. **Explore 2–3 Architectural Approaches with Tradeoffs**:
   - *Example: Verifying Multi-Path File Parity*:
     - *Approach A (File Size Comparison)*: Compare byte counts only. Fast, but misses internal bit flips and character encoding mutations.
     - *Approach B (Cryptographic SHA256 Digest Audit)*: Compute SHA256 for all copies and assert exact string match. Computationally negligible for text/code, $100\%$ tamper-proof, and catches line-ending corruption.
     - *Approach C (Git Tree Hash Comparison)*: Relies on git index. Fails when mirror destinations are outside git working trees.
   - *Recommendation*: Approach B provides cryptographic certainty across arbitrary filesystem locations.
3. **Structured Design Documentation**:
   - Document script logic, paths, hash algorithms, and failure remediation paths.
4. **Builder Check & Self-Review**:
   - Ensure paths with spaces (e.g. `D:\Agents workespaces`) are properly quoted in all commands.
5. **Hard Gate**:
   - Do NOT run destructive sync commands until mirror paths and checksum routines are verified.

### Workflow 2: Executing Static Analysis & Automated Tests
1. Navigate to the Flutter app directory:
   ```powershell
   Set-Location -Path "D:\E-player\app"
   ```
2. Run Flutter static analysis:
   ```powershell
   flutter analyze
   ```
   Confirm output displays `No issues found!`.
3. Run the automated test suites:
   ```powershell
   flutter test test/unit/
   flutter test test/e2e/
   ```
4. Verify all tests pass with $0$ failures.

### Workflow 3: Scanning for Prohibited Placeholders
1. Run recursive scan across all Dart and C++ source files:
   ```powershell
   Get-ChildItem -Path "D:\E-player\app\lib", "D:\E-player\native\engine" -Recurse -Include *.dart, *.cpp, *.h | Select-String -Pattern "TODO|FIXME|throw UnimplementedError|TBD"
   ```
2. Verify that the output is completely empty.

### Workflow 4: Synchronizing Deliverables Across Multi-Path Mirrors
1. Copy skills from `D:\E-player\skills\` to `D:\Agents workespaces\skills\` and `D:\overload\skills\`:
   ```powershell
   $Skills = @("eplayer-flutter-video-arch", "eplayer-mpv-vlc-parity", "eplayer-native-neural-ffi", "eplayer-verification-guardrail")
   foreach ($s in $Skills) {
       $src = "D:\E-player\skills\$s\SKILL.md"
       $dst1 = "D:\Agents workespaces\skills\$s\SKILL.md"
       $dst2 = "D:\overload\skills\$s\SKILL.md"
       
       New-Item -ItemType Directory -Force -Path (Split-Path $dst1) | Out-Null
       New-Item -ItemType Directory -Force -Path (Split-Path $dst2) | Out-Null
       Copy-Item -Path $src -Destination $dst1 -Force
       Copy-Item -Path $src -Destination $dst2 -Force
   }
   ```

### Workflow 5: Running Cryptographic SHA256 Parity Audits
1. Execute Python parity audit:
   ```python
   import hashlib
   from pathlib import Path

   def verify_parity(primary: str, mirror1: str, mirror2: str):
       def get_sha256(p: str) -> str:
           h = hashlib.sha256()
           with open(p, "rb") as f:
               while chunk := f.read(65536):
                   h.update(chunk)
           return h.hexdigest()

       h0 = get_sha256(primary)
       h1 = get_sha256(mirror1)
       h2 = get_sha256(mirror2)
       assert h0 == h1 == h2, f"Mismatch: {h0} vs {h1} vs {h2}"
       print(f"Verified {Path(primary).name}: {h0}")
   ```
2. Confirm zero assertion errors.

### Workflow 6: Executing Hermes in Non-Interactive Unattended Mode
1. Prepare prompt in a temporary text file `prompt.txt`.
2. Launch Hermes with profile `coder`:
   ```powershell
   & "C:\Users\Admin\AppData\Local\hermes\bin\hermes.exe" -p coder chat --yolo --oneshot -Q --query-file "prompt.txt"
   ```
3. Inspect output log for completion status and errors.

## Common Mistakes & Prohibitions
- **Prohibited: Claiming Success without Test Execution**: Never declare a task complete without running `flutter analyze` and `flutter test` and verifying clean output.
- **Prohibited: Leaving TODO Comments in Code**: Any `TODO` or `FIXME` comment constitutes an automatic verification failure.
- **Prohibited: Mirroring without SHA256 Verification**: Copying files without verifying their cryptographic checksums leaves corruptions and line-ending translations undetected.
- **Prohibited: Storing Large Build Artifacts on Drive C:**: Keep heavy build caches (`.dart_tool`, `build/`, `.gradle`) strictly on Drive `D:`.
- **Prohibited: Interactive Prompts in CI/Autonomous Jobs**: Always use `--yolo` and `--oneshot` when invoking Hermes non-interactively to prevent indefinite blocking on confirmation prompts.
