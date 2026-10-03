---
name: e-player-python-ai-engineering
version: 1.0.0
project: E-Player
purpose: Python development, model engineering, conversion, validation, benchmarking, and offline tooling for E-Player.
runtime_role: Development/tooling/reference implementation only; NOT the required production runtime on Android/iOS.
loads_with: E_PLAYER_AI_SKILL.md
---

# E-Player Python Engineering Skill

## 0. PURPOSE

Use Python for the parts of E-Player that benefit from scientific computing, ML experimentation, model conversion, quality evaluation, benchmarking, dataset tooling, and reference implementations.

Python is **not** the required runtime engine inside the production smartphone app.

The production mobile app should consume validated, mobile-compatible model artifacts through a native/mobile inference layer.

---

# 1. PYTHON RESPONSIBILITIES

Python may be used for:

- model experimentation;
- Real-ESRGAN model testing;
- RIFE model testing;
- depth-model testing;
- audio enhancement research/prototyping;
- model conversion;
- ONNX export;
- ONNX graph validation;
- quantization experiments;
- benchmark scripts;
- test-corpus generation;
- image/video frame extraction;
- quality metrics;
- regression testing;
- reference inference;
- model metadata generation;
- checksum generation;
- asset packaging;
- release validation;
- offline developer utilities.

Python must not become a hidden production dependency of the mobile application.

---

# 2. PYTHON ENVIRONMENT

Use a reproducible environment.

Recommended:
- Python 3.11 or the version explicitly pinned by the project.
- `pyproject.toml` as the preferred package/build configuration.
- `uv`, Poetry, or another documented dependency manager.
- Lock dependencies for reproducibility.
- Separate CPU and GPU environments when needed.

Never assume that a developer has CUDA installed.

The default Python toolchain should remain able to run model validation/metadata tooling without NVIDIA-specific dependencies.

---

# 3. PROJECT STRUCTURE

Recommended:

```text
python/
  pyproject.toml
  README.md
  src/
    eplayer_ai/
      __init__.py
      config/
      models/
      inference/
      conversion/
      quantization/
      preprocessing/
      postprocessing/
      audio/
      video/
      metrics/
      benchmarking/
      registry/
      validation/
      packaging/
      cli/
  tests/
    unit/
    integration/
    regression/
  scripts/
  models/
    manifests/
  benchmarks/
  datasets/
    manifests/
  outputs/
```

Keep Python modules small and composable.

---

# 4. DEPENDENCY POLICY

Prefer stable, widely supported packages.

Typical categories:
- PyTorch for research/reference inference;
- ONNX / ONNX Runtime for validation;
- NumPy for numerical work;
- OpenCV where appropriate;
- FFmpeg command-line integration for media preprocessing/export tests;
- Pillow for image utilities;
- pandas only when tabular analysis is actually needed.

Do not import an enormous framework for a task that can be done with a small standard-library module.

---

# 5. MODEL REGISTRY

Every model must have a manifest.

Example:

```yaml
id: realesrgan_general_x4
version: "1.0.0"
task: spatial_super_resolution
license: "document exact license"
format:
  reference: pytorch
  mobile: onnx
scale: 4
supported_precisions:
  - fp32
  - fp16
  - int8
providers:
  - cpu
  - xnnpack
  - coreml
  - nnapi
min_ram_mb: 2048
recommended_ram_mb: 4096
input_layout: NCHW
color_space: RGB
tile_required_above:
  width: 1920
  height: 1080
fallback_model: null
sha256: "generated-at-build"
```

Do not hardcode model details across many scripts.

---

# 6. MODEL CONVERSION WORKFLOW

Every model intended for mobile must go through:

1. obtain/reference model;
2. verify license;
3. pin source version/commit;
4. load reference model;
5. establish reference outputs;
6. export to ONNX;
7. verify ONNX graph;
8. run ONNX Runtime reference;
9. compare output with source model;
10. test supported input shapes;
11. test dynamic/static shape assumptions;
12. test quantization;
13. benchmark latency and memory;
14. validate model on representative devices/runtimes;
15. generate manifest;
16. compute checksum;
17. package artifact.

No model enters the app solely because conversion succeeded.

---

# 7. NUMERICAL VALIDATION

For every converted model compare:
- tensor shapes;
- dtype;
- min/max;
- mean/std;
- image/audio output;
- task-specific quality metrics.

Use tolerances appropriate to the model.

For image enhancement compare:
- PSNR where meaningful;
- SSIM where meaningful;
- perceptual metrics where available;
- artifact rates;
- visual regression snapshots.

For audio enhancement compare:
- SNR improvements where measurable;
- speech intelligibility metrics if available;
- clipping;
- loudness;
- spectral distortion;
- listening-test corpus.

A metric is evidence, not proof of subjective quality.

---

# 8. TILE-BASED VIDEO INFERENCE

Large frames can exceed mobile memory.

Implement a reusable tiling utility.

Requirements:
- tile size configurable;
- overlap configurable;
- edge-safe padding;
- deterministic stitching;
- optional blending;
- no seam amplification;
- bounded memory;
- cancellation support.

Pseudo-flow:

```text
frame
  -> color conversion
  -> tile split
  -> model inference per tile
  -> overlap-aware stitch
  -> output color conversion
```

The Python reference implementation should match the native implementation closely enough for regression tests.

---

# 9. RIFE REFERENCE PIPELINE

The Python toolchain should be able to validate:
- two input frames;
- intermediate frame generation;
- timestamps;
- 2x interpolation;
- scene-change detection;
- output ordering.

Maintain explicit tests for:
- static scenes;
- linear motion;
- fast motion;
- occlusion;
- cuts;
- flashes.

The mobile implementation must not be judged only on a synthetic static benchmark.

---

# 10. AUDIO REFERENCE PIPELINE

For audio tools:
- decode through a reproducible path;
- normalize sample representation;
- preserve sample rate metadata;
- support mono/stereo explicitly;
- run enhancement;
- prevent clipping;
- compare input/output loudness.

Reference pipelines may use:
- RNNoise-class noise suppression;
- DeepFilterNet-class speech enhancement;
- DSP filters.

Do not force speech enhancement onto music-only tracks by default.

---

# 11. QUANTIZATION

Evaluate:
- FP32;
- FP16;
- INT8 where supported.

For each model record:
- model size;
- latency;
- memory;
- output error;
- visible quality change.

Never assume INT8 is always better. It is a trade-off.

Quantization must be validated per model/operator/provider.

---

# 12. BENCHMARKING

Build scripts that report:

```text
model
provider
precision
input_resolution
batch
latency_ms
fps
peak_ram_mb
peak_vram_mb_if_available
power_or_thermal_notes
quality_metrics
```

Benchmark:
- cold start;
- warm inference;
- sustained inference;
- repeated model load/unload;
- concurrent audio/video where applicable.

Never compare two implementations using different input sizes or preprocessing.

---

# 13. REPRODUCIBILITY

Every benchmark output must record:
- Python version;
- package versions;
- model ID/version;
- model checksum;
- OS;
- CPU/GPU;
- runtime version;
- preprocessing parameters;
- timestamp.

Store machine-readable results as JSON/CSV.

---

# 14. TEST CORPUS

Create a versioned test corpus manifest.

Minimum categories:
- 360p/480p/720p/1080p source;
- heavy compression;
- anime/animation;
- faces;
- text;
- foliage/detail;
- low light;
- noise;
- motion blur;
- fast motion;
- scene cuts;
- dialogue;
- music;
- mixed audio.

Do not commit copyrighted media into the repository without permission.

Use short synthetic or licensed clips where appropriate.

---

# 15. MODEL QUALITY GUARDRAILS

AI enhancement may hallucinate texture.

Quality validation must look for:
- invented text;
- unnatural faces;
- edge ringing;
- oversharpening;
- repeated texture;
- temporal flicker;
- motion warping;
- subtitle corruption.

A model with better PSNR can still look worse perceptually.

---

# 16. FFMPEG TOOLING

Use FFmpeg for controlled preprocessing and reference workflows.

Typical Python tasks:
- extract frames;
- extract audio;
- create test clips;
- mux enhanced video/audio;
- verify stream metadata;
- verify frame counts;
- verify timestamps.

Always use subprocess argument arrays, not unsafe shell interpolation.

Example pattern:

```python
from subprocess import run

cmd = [
    "ffmpeg",
    "-hide_banner",
    "-y",
    "-i", input_path,
    "-vf", "fps=30",
    output_path,
]

run(cmd, check=True)
```

Validate input paths and generated outputs before processing.

---

# 17. CLI DESIGN

Prefer a stable CLI for repeatable tooling.

Example:

```text
eplayer-ai inspect-model model.onnx
eplayer-ai validate-model model.onnx --reference reference.pt
eplayer-ai benchmark model.onnx --provider cpu
eplayer-ai convert-model source.pt --output model.onnx
eplayer-ai extract-frames input.mp4 --fps 1
eplayer-ai quality-report input.mp4 output.mp4
```

Commands should return meaningful exit codes.

---

# 18. ERROR HANDLING

Python tooling must:
- fail early on missing models;
- report exact dependency/version problems;
- validate file existence;
- validate media metadata;
- write outputs atomically;
- clean temporary directories;
- preserve logs for failed conversion/benchmark runs.

Never silently continue after model conversion corruption.

---

# 19. SECURITY

Avoid:
- `eval`;
- arbitrary code execution;
- unsafe pickle loading from untrusted sources;
- shell commands built from raw user strings.

When loading external models:
- verify provenance;
- record source;
- verify checksum;
- document serialization format;
- prefer safer/exported formats when possible.

---

# 20. MOBILE BRIDGE CONTRACT

The Python side should produce artifacts that the native mobile runtime can consume.

The artifact boundary should be explicit:

```text
Python research/reference
        |
        +--> ONNX/model artifacts
        +--> metadata manifest
        +--> benchmark expectations
        +--> golden outputs
        v
Native mobile inference runtime
        |
        v
Flutter application
```

Python should not leak internal classes or Python object assumptions into Dart/FFI.

---

# 21. CI REQUIREMENTS

CI should run at minimum:
- formatting;
- lint/static checks;
- unit tests;
- model manifest validation;
- ONNX graph validation for tracked models;
- deterministic small benchmark smoke test;
- checksum verification.

Heavy GPU benchmarks can run in a dedicated pipeline.

---

# 22. DEFINITION OF DONE FOR A MODEL

A model is production-candidate only when:
- license is documented;
- source version is pinned;
- reference output is recorded;
- mobile artifact exists;
- ONNX/runtime validation passes;
- numerical tolerance is documented;
- memory behavior is measured;
- latency is measured;
- quality regression passes;
- manifest/checksum generated;
- mobile compatibility is documented;
- fallback model/provider is specified.

---

# 23. PYTHON AGENT BEHAVIOR

When asked to add a model or Python feature:

1. inspect existing registry and tooling;
2. reuse existing utilities;
3. define expected inputs/outputs;
4. write a minimal reference test;
5. implement;
6. benchmark;
7. validate;
8. update manifest/documentation;
9. report limitations.

Never hide a model limitation just to make a benchmark look better.

