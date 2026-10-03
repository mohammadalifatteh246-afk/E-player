# E-Player AI Skills Pack — Usage Guide

This pack contains two reusable skills:

1. `E_PLAYER_AI_SKILL.md`
   - Master skill for building the complete E-Player application.
   - Covers architecture, mobile compatibility, media playback, AI video enhancement, frame interpolation, audio enhancement, subtitles, 2D→3D, export, performance, privacy, testing, and AI-agent behavior.

2. `E_PLAYER_PYTHON_SKILL.md`
   - Dedicated Python/ML engineering skill.
   - Covers model research, Real-ESRGAN/RIFE/depth/audio tooling, ONNX conversion, quantization, benchmarking, FFmpeg tooling, quality validation, model registry and CI.

## Recommended loading order

### For a general AI coding agent
Load:

`E_PLAYER_AI_SKILL.md`

Then provide the project PRD and implementation plan as source-of-truth documents.

### For an AI implementing Python/model tooling
Load:

`E_PLAYER_AI_SKILL.md`
and then:
`E_PLAYER_PYTHON_SKILL.md`

### For a multi-agent setup

Recommended agent roles:

- Product/Architecture Agent:
  E_PLAYER_AI_SKILL.md

- Flutter/Dart Agent:
  E_PLAYER_AI_SKILL.md

- Native/FFI Agent:
  E_PLAYER_AI_SKILL.md

- Python/ML Agent:
  E_PLAYER_PYTHON_SKILL.md

- QA/Performance Agent:
  E_PLAYER_AI_SKILL.md + E_PLAYER_PYTHON_SKILL.md

## Important architectural rule

Python is a development/reference/model-engineering environment. It is NOT the required production runtime inside Android/iOS.

The mobile application should use a native/mobile inference layer such as ONNX Runtime Mobile plus validated platform accelerators.

## Suggested prompt wrapper

Paste this after loading the skill:

“Use the loaded E-Player skill as an engineering policy. Inspect the existing repository first. Follow the E-Player PRD and implementation plan as product source of truth. Implement only real functionality, preserve offline processing, use capability-aware fallbacks, and never fake AI status. Before coding, identify the affected modules and tests. After coding, run the relevant tests/build checks and report actual limitations.”
