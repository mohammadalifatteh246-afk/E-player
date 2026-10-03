#ifndef EPLAYER_ENGINE_H
#define EPLAYER_ENGINE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#define EPLAYER_EXPORT __declspec(dllexport)
#else
#define EPLAYER_EXPORT __attribute__((visibility("default")))
#endif

// Opaque handles
typedef struct EPlayerEngine* EPEngineHandle;
typedef struct EPlayerModel* EPModelHandle;
typedef struct EPFrameBuffer* EPFrameHandle;

// Engine Initialization
EPLAYER_EXPORT EPEngineHandle eplayer_engine_create();
EPLAYER_EXPORT void eplayer_engine_destroy(EPEngineHandle engine);

// Model Management
EPLAYER_EXPORT EPModelHandle eplayer_model_load(EPEngineHandle engine, const char* model_path, const char* provider, int num_threads);
EPLAYER_EXPORT void eplayer_model_unload(EPEngineHandle engine, EPModelHandle model);

// Frame / Memory Pool Management
// Acquires a buffer from the pool (avoids per-frame allocation)
EPLAYER_EXPORT EPFrameHandle eplayer_frame_acquire(EPEngineHandle engine, int width, int height, int channels);
EPLAYER_EXPORT void eplayer_frame_release(EPEngineHandle engine, EPFrameHandle frame);
EPLAYER_EXPORT uint8_t* eplayer_frame_get_data(EPFrameHandle frame);

// Inference execution
// Returns 0 on success, < 0 on error
EPLAYER_EXPORT int eplayer_frame_submit(EPEngineHandle engine, EPModelHandle model, EPFrameHandle input_frame, EPFrameHandle* output_frame);

// Queue and Cancelation
EPLAYER_EXPORT void eplayer_job_cancel_all(EPEngineHandle engine);
EPLAYER_EXPORT void eplayer_queue_invalidate(EPEngineHandle engine); // Phase 5B: Flush RIFE buffers on seek
EPLAYER_EXPORT int eplayer_get_queue_depth(EPEngineHandle engine);

// RIFE Interpolation Config (Phase 5)
EPLAYER_EXPORT void eplayer_set_rife_config(EPEngineHandle engine, int target_fps, bool enable_scene_cut_detection);
EPLAYER_EXPORT void eplayer_set_audio_timestamp_offset(EPEngineHandle engine, int64_t offset_ms); // Phase 5C

// Audio Enhancement Config (Phase 6)
// Phase 6A: DSP
EPLAYER_EXPORT void eplayer_set_audio_dsp_config(EPEngineHandle engine, bool enable_eq, bool enable_normalization, bool enable_compressor, bool enable_dialogue_boost, bool enable_night_mode);
// Phase 6B: AI speech/noise
EPLAYER_EXPORT void eplayer_set_audio_ai_config(EPEngineHandle engine, bool enable_rnnoise, float strength);
// Bypass Audio Enhancement
EPLAYER_EXPORT void eplayer_bypass_audio_enhancement(EPEngineHandle engine, bool bypass);

// Phase 8: Advanced Features
// Phase 8A: ASR / Subtitle Generation
EPLAYER_EXPORT void eplayer_generate_subtitles(EPEngineHandle engine, const char* audio_path, const char* output_srt_path);
// Phase 8B: 2D to 3D Depth
EPLAYER_EXPORT void eplayer_set_depth_config(EPEngineHandle engine, bool enable_sbs, float depth_strength, float convergence);
// Phase 8C & Exit Criteria: Capability & Thermal Gating
EPLAYER_EXPORT bool eplayer_can_enable_pipeline(EPEngineHandle engine, bool needs_spatial, bool needs_temporal, bool needs_audio, bool needs_depth);

// Error Reporting
EPLAYER_EXPORT const char* eplayer_get_last_error(EPEngineHandle engine);

#ifdef __cplusplus
}
#endif

#endif // EPLAYER_ENGINE_H
