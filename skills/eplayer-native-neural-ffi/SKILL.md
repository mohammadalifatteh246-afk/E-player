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

# E-Player Native Neural AI Engine & Dart FFI Operations

## When to Use
- Compiling, updating, or debugging the C++17 native neural engine located in `D:\E-player\native\engine`.
- Managing bounded GPU/VRAM frame buffer pools (`EPFrameBuffer`) and enforcing the `kMaxQueueDepth = 8` memory leak ceiling.
- Configuring tiled spatial super-resolution pipelines (Real-ESRGAN x4, Anime4K, FSRCNN) with edge feathering and Laplacian detail kernels.
- Operating temporal frame interpolation (RIFE 60fps / 120fps), scene cut detection, and seek queue invalidation (`eplayer_queue_invalidate`).
- Authoring or updating type-safe Dart FFI bridge bindings in `lib/core/ffi/engine_bindings.dart`.
- Running CMake builds for the Windows desktop native library (`eplayer_engine.dll`) and verifying cross-platform ABI exports.

## Quick Reference Table

| Target / Subsystem | Source / Command | Expected Outcome |
| :--- | :--- | :--- |
| Native C++ Engine | `native/engine/include/eplayer_engine.h` | Pure C ABI export definitions with zero C++ mangling |
| CMake Build | `cmake -B build -S native/engine` | Generates build system targeting `eplayer_engine.dll` |
| Bounded Memory Pool | `kMaxQueueDepth = 8` in `eplayer_engine.cpp` | Clamps maximum in-flight frames; eliminates VRAM runaway leaks |
| Super-Resolution | `eplayer_frame_submit_tiled` | Real-ESRGAN x4 spatial upscaling with Laplacian edge blending |
| RIFE 60 FPS | `eplayer_set_rife_config` | Bidirectional optical flow motion interpolation |
| Seek Invalidation | `eplayer_queue_invalidate` | Flushes pending interpolated frames upon seek; prevents ghosting |
| Dart FFI Bindings | `lib/core/ffi/engine_bindings.dart` | Safe dynamic library loading and typed struct pointer mapping |

## Core Subsystems & Technical Specifications

### 1. Native C++17 Engine Architecture & Build Integration
The native engine is located in `D:\E-player\native\engine` and compiles to a high-performance shared library (`eplayer_engine.dll` on Windows, `libeplayer_engine.so` on Linux, `libeplayer_engine.dylib` on macOS):
- **Language Standard**: C++17 (`set(CMAKE_CXX_STANDARD 17)`).
- **Export Header**: `native/engine/include/eplayer_engine.h` defines a pure C ABI (`extern "C"`) to guarantee ABI stability and direct Dart FFI compatibility.
- **Windows Integration**: Connected directly into Flutter Windows build via `add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../../native/engine" engine)` in `app/windows/CMakeLists.txt`.

### 2. Bounded Memory Pooling & Frame Lifecycle
Unbounded neural frame processing causes severe VRAM runaway and out-of-memory crashes during real-time video playback:
- **Static Buffer Pool**: Pre-allocates up to 16 static `EPFrameBuffer` instances during `eplayer_engine_init`:
  ```cpp
  constexpr int kMaxPoolSize = 16;
  constexpr int kMaxQueueDepth = 8;
  ```
- **Lifecycle API**:
  - `eplayer_frame_acquire(int width, int height, int format)`: Obtains a recycled frame buffer from the pool. Returns `nullptr` if pool exhausted.
  - `eplayer_frame_get_data(EPFrameBuffer* frame, uint8_t** out_data, int* out_stride)`: Returns raw native byte pointers for direct GPU texture upload.
  - `eplayer_frame_release(EPFrameBuffer* frame)`: Returns the buffer to the pool; resets reference counters.
- **Queue Depth Clamp**: If the in-flight processing queue exceeds `kMaxQueueDepth = 8`, subsequent frame submissions block or drop safely rather than expanding memory usage.

### 3. Tiled Spatial Super-Resolution with Laplacian Detail Kernels
Upscaling full $1080\text{p}$ or $4\text{K}$ frames in a single inference pass exceeds typical GPU memory limits:
- **Tiled Processing (`eplayer_frame_submit_tiled`)**:
  - Splits source frame into rectangular tiles (e.g. $256 \times 256$ or $512 \times 512$ with $32\text{px}$ overlap border).
  - Overlap regions are blended using a linear feathering ramp to prevent visible seam artifacts:
    $$W_{\text{blend}}(x) = \frac{x - x_{\text{start}}}{\text{overlap\_size}}$$
  - **Laplacian Detail Enhancement**: Applies a $3 \times 3$ high-pass Laplacian kernel to the upscaled luminance plane to restore fine textures:
    $$K_{\text{laplacian}} = \begin{bmatrix} 0 & -1 & 0 \\ -1 & 4 & -1 \\ 0 & -1 & 0 \end{bmatrix}$$
    $$I_{\text{enhanced}} = I_{\text{upscaled}} + \alpha \times (I_{\text{upscaled}} * K_{\text{laplacian}})$$
  - Supported Models: Real-ESRGAN x4 (photorealistic), Anime4K (anime/line-art), FSRCNN (ultra-fast).

### 4. RIFE 60 FPS Bidirectional Frame Interpolation
Real-Time Intermediate Flow Estimation (RIFE) interpolates $24\text{fps}$ and $30\text{fps}$ content up to $60\text{fps}$ or $120\text{fps}$:
- **Optical Flow & Motion Vectors**: Computes forward ($F_{0 \rightarrow 1}$) and backward ($F_{1 \rightarrow 0}$) motion fields between consecutive frames $I_0$ and $I_1$.
- **Scene Cut Detection**: Evaluates frame-to-frame mean squared error (MSE) and structural similarity index (SSIM). If $\text{MSE} > \theta_{\text{cut}}$, interpolation is bypassed for that frame to prevent horrific morphing artifacts across scene transitions.
- **Seek Queue Invalidation (`eplayer_queue_invalidate`)**:
  - Whenever the user initiates a seek jump, the player calls `eplayer_queue_invalidate`.
  - Immediately purges all buffered historical frames and resets optical flow state, preventing "ghost" frames from previous scenes from rendering after a jump.

### 5. Audio AI Denoising & Automatic Subtitles
- **Speech Denoising**: RNNoise recurrent neural network pipeline configured via `eplayer_set_audio_ai_config` suppresses background fan noise and room reverberation in real time.
- **Automatic Subtitles**: `eplayer_generate_subtitles` dispatches local Whisper inference in a background worker thread.

### 6. Typed Dart FFI Bridge (`engine_bindings.dart`)
Located in `app/lib/core/ffi/engine_bindings.dart`:
- Maps C structs to Dart `Struct` subclasses:
  ```dart
  final class EPFrameBuffer extends Struct {
    @Int32()
    external int width;
    @Int32()
    external int height;
    @Int32()
    external int format;
    external Pointer<Uint8> data;
    @Int32()
    external int stride;
  }
  ```
- Dynamic Library Resolution:
  ```dart
  DynamicLibrary _loadLibrary() {
    if (Platform.isWindows) return DynamicLibrary.open('eplayer_engine.dll');
    if (Platform.isLinux) return DynamicLibrary.open('libeplayer_engine.so');
    if (Platform.isMacOS) return DynamicLibrary.open('libeplayer_engine.dylib');
    throw UnsupportedError('Unsupported operating system');
  }
  ```

## Operational Workflows

### Workflow 1: Brainstorming Pre-Flight Gate for Native C++ & FFI Changes
Before touching C++ source or Dart FFI bindings:

1. **Intent Discovery ("Look Before You Ask")**:
   - Inspect `native/engine/include/eplayer_engine.h` and `app/lib/core/ffi/engine_bindings.dart`.
   - Determine whether the modification alters the C ABI signature, struct alignment, or memory ownership semantics.
2. **Explore 2–3 Architectural Approaches with Tradeoffs**:
   - *Example: Implementing Frame Buffer Memory Management*:
     - *Approach A (Dynamic Heap Allocation per Frame)*: Allocate `malloc`/`free` on every video frame. Simpler code, but catastrophic memory fragmentation and CPU overhead at 60fps (60 allocations/sec).
     - *Approach B (Bounded Pre-Allocated Static Pool)*: Pre-allocate 16 fixed `EPFrameBuffer` instances with a strict `kMaxQueueDepth = 8` queue clamp. Zero runtime allocation overhead, zero fragmentation, deterministic VRAM ceiling, and absolute leak immunity.
     - *Approach C (Shared Memory IPC)*: Stream frames via named pipes. Massive inter-process serialization overhead.
   - *Recommendation*: Approach B is strictly required for real-time video playback performance.
3. **Structured Design Documentation**:
   - Record struct field layouts, byte alignment requirements, memory ownership rules, and synchronization primitives.
4. **Builder Check & Self-Review**:
   - Verify 32-bit and 64-bit alignment, endianness safety, and thread safety of pool acquire/release.
5. **Hard Gate**:
   - Do NOT edit C++ or FFI files until the memory model is documented and approved.

### Workflow 2: Building and Testing the Native Engine via CMake
1. Navigate to the native engine directory:
   ```powershell
   Set-Location -Path "D:\E-player\native\engine"
   ```
2. Configure CMake build directory:
   ```powershell
   cmake -B build -S . -DCMAKE_BUILD_TYPE=Release
   ```
3. Compile the shared library target:
   ```powershell
   cmake --build build --config Release
   ```
4. Confirm `build/Release/eplayer_engine.dll` was generated.
5. Copy or link `eplayer_engine.dll` into the Flutter desktop build output directory.

### Workflow 3: Integrating Super-Resolution Tiling with Overlap Blending
1. Initialize the super-resolution pipeline:
   ```c
   EPSuperResConfig config;
   config.model_type = EP_SR_MODEL_REAL_ESRGAN_X4;
   config.tile_size = 256;
   config.overlap = 32;
   config.detail_enhancement = 1.2f;
   eplayer_set_superres_config(&config);
   ```
2. Submit frames for processing:
   ```c
   EPFrameBuffer* in_frame = eplayer_frame_acquire(1920, 1080, EP_FMT_RGBA);
   // Fill in_frame->data
   EPFrameBuffer* out_frame = nullptr;
   int status = eplayer_frame_submit_tiled(in_frame, &out_frame);
   // Process out_frame, then release both
   eplayer_frame_release(in_frame);
   eplayer_frame_release(out_frame);
   ```

### Workflow 4: Configuring RIFE 60 FPS Interpolation and Seek Invalidation
1. Configure RIFE interpolation:
   ```c
   EPRifeConfig rife_cfg;
   rife_cfg.target_fps = 60.0f;
   rife_cfg.scene_cut_threshold = 0.35f;
   eplayer_set_rife_config(&rife_cfg);
   ```
2. Wire seek listener in Dart:
   ```dart
   player.stream.position.listen((pos) {
     // If user initiates a seek jump, invalidate the native interpolation queue
     if (isUserSeeking) {
       engineBindings.eplayerQueueInvalidate();
     }
   });
   ```

### Workflow 5: Generating and Verifying Typed Dart FFI Bindings
1. Inspect `native/engine/include/eplayer_engine.h` for newly added C functions.
2. In `app/lib/core/ffi/engine_bindings.dart`, declare the C function typedef and Dart function signature.
3. Lookup the native symbol via `dylib.lookupFunction<NativeType, DartType>('function_name')`.
4. Wrap calls with type-safe Dart wrappers ensuring memory pointers are freed or released after execution.
5. Verify via unit tests that native memory does not leak.

## Common Mistakes & Prohibitions
- **Prohibited: Unbounded Frame Queues**: Never push frames to the neural pipeline without checking `kMaxQueueDepth = 8`. Unbounded queues will consume 8GB+ of VRAM in seconds and crash the GPU driver.
- **Prohibited: Passing C++ Objects Across FFI**: Never export C++ classes, `std::string`, `std::vector`, or virtual tables across the FFI boundary. Only export pure C types (`int`, `float`, raw pointers, C-compatible structs).
- **Prohibited: Forgetting Queue Invalidation on Seek**: Omitting `eplayer_queue_invalidate` causes the RIFE interpolation filter to blend frames from the pre-seek position with post-seek frames, causing severe visual artifacting.
- **Prohibited: Hardcoding Library Paths**: Always use platform-conditional resolution (`Platform.isWindows`, `Platform.isLinux`, `Platform.isMacOS`).
- **Prohibited: Double-Freeing Frame Buffers**: Never call `eplayer_frame_release` twice on the same buffer pointer. Always set pointers to `nullptr` after release.
