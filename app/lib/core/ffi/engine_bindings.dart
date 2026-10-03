import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'dart:io';

// Opaque types
final class EPEngineHandle extends ffi.Opaque {}
final class EPModelHandle extends ffi.Opaque {}
final class EPFrameHandle extends ffi.Opaque {}

typedef EngineCreateNative = ffi.Pointer<EPEngineHandle> Function();
typedef EngineCreateDart = ffi.Pointer<EPEngineHandle> Function();

typedef EngineDestroyNative = ffi.Void Function(ffi.Pointer<EPEngineHandle>);
typedef EngineDestroyDart = void Function(ffi.Pointer<EPEngineHandle>);

typedef ModelLoadNative = ffi.Pointer<EPModelHandle> Function(ffi.Pointer<EPEngineHandle>, ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, ffi.Int32);
typedef ModelLoadDart = ffi.Pointer<EPModelHandle> Function(ffi.Pointer<EPEngineHandle>, ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, int);

typedef ModelUnloadNative = ffi.Void Function(ffi.Pointer<EPEngineHandle>, ffi.Pointer<EPModelHandle>);
typedef ModelUnloadDart = void Function(ffi.Pointer<EPEngineHandle>, ffi.Pointer<EPModelHandle>);

typedef FrameAcquireNative = ffi.Pointer<EPFrameHandle> Function(ffi.Pointer<EPEngineHandle>, ffi.Int32, ffi.Int32, ffi.Int32);
typedef FrameAcquireDart = ffi.Pointer<EPFrameHandle> Function(ffi.Pointer<EPEngineHandle>, int, int, int);

typedef FrameReleaseNative = ffi.Void Function(ffi.Pointer<EPEngineHandle>, ffi.Pointer<EPFrameHandle>);
typedef FrameReleaseDart = void Function(ffi.Pointer<EPEngineHandle>, ffi.Pointer<EPFrameHandle>);

typedef FrameGetDataNative = ffi.Pointer<ffi.Uint8> Function(ffi.Pointer<EPFrameHandle>);
typedef FrameGetDataDart = ffi.Pointer<ffi.Uint8> Function(ffi.Pointer<EPFrameHandle>);

typedef FrameSubmitNative = ffi.Int32 Function(ffi.Pointer<EPEngineHandle>, ffi.Pointer<EPModelHandle>, ffi.Pointer<EPFrameHandle>, ffi.Pointer<ffi.Pointer<EPFrameHandle>>);
typedef FrameSubmitDart = int Function(ffi.Pointer<EPEngineHandle>, ffi.Pointer<EPModelHandle>, ffi.Pointer<EPFrameHandle>, ffi.Pointer<ffi.Pointer<EPFrameHandle>>);

typedef JobCancelAllNative = ffi.Void Function(ffi.Pointer<EPEngineHandle>);
typedef JobCancelAllDart = void Function(ffi.Pointer<EPEngineHandle>);

typedef GetQueueDepthNative = ffi.Int32 Function(ffi.Pointer<EPEngineHandle>);
typedef GetQueueDepthDart = int Function(ffi.Pointer<EPEngineHandle>);

typedef GetLastErrorNative = ffi.Pointer<Utf8> Function(ffi.Pointer<EPEngineHandle>);
typedef GetLastErrorDart = ffi.Pointer<Utf8> Function(ffi.Pointer<EPEngineHandle>);

// Phase 5: RIFE specific
typedef QueueInvalidateNative = ffi.Void Function(ffi.Pointer<EPEngineHandle>);
typedef QueueInvalidateDart = void Function(ffi.Pointer<EPEngineHandle>);

typedef SetRifeConfigNative = ffi.Void Function(ffi.Pointer<EPEngineHandle>, ffi.Int32, ffi.Bool);
typedef SetRifeConfigDart = void Function(ffi.Pointer<EPEngineHandle>, int, bool);

typedef SetAudioTimestampOffsetNative = ffi.Void Function(ffi.Pointer<EPEngineHandle>, ffi.Int64);
typedef SetAudioTimestampOffsetDart = void Function(ffi.Pointer<EPEngineHandle>, int);

// Phase 6: Audio specific
typedef SetAudioDspConfigNative = ffi.Void Function(ffi.Pointer<EPEngineHandle>, ffi.Bool, ffi.Bool, ffi.Bool, ffi.Bool, ffi.Bool);
typedef SetAudioDspConfigDart = void Function(ffi.Pointer<EPEngineHandle>, bool, bool, bool, bool, bool);

typedef SetAudioAiConfigNative = ffi.Void Function(ffi.Pointer<EPEngineHandle>, ffi.Bool, ffi.Float);
typedef SetAudioAiConfigDart = void Function(ffi.Pointer<EPEngineHandle>, bool, double);

typedef BypassAudioEnhancementNative = ffi.Void Function(ffi.Pointer<EPEngineHandle>, ffi.Bool);
typedef BypassAudioEnhancementDart = void Function(ffi.Pointer<EPEngineHandle>, bool);

// Phase 8: Advanced Features
typedef GenerateSubtitlesNative = ffi.Void Function(ffi.Pointer<EPEngineHandle>, ffi.Pointer<Utf8>, ffi.Pointer<Utf8>);
typedef GenerateSubtitlesDart = void Function(ffi.Pointer<EPEngineHandle>, ffi.Pointer<Utf8>, ffi.Pointer<Utf8>);

typedef SetDepthConfigNative = ffi.Void Function(ffi.Pointer<EPEngineHandle>, ffi.Bool, ffi.Float, ffi.Float);
typedef SetDepthConfigDart = void Function(ffi.Pointer<EPEngineHandle>, bool, double, double);

typedef CanEnablePipelineNative = ffi.Bool Function(ffi.Pointer<EPEngineHandle>, ffi.Bool, ffi.Bool, ffi.Bool, ffi.Bool);
typedef CanEnablePipelineDart = bool Function(ffi.Pointer<EPEngineHandle>, bool, bool, bool, bool);

class EPlayerEngineBindings {
  late final ffi.DynamicLibrary _lib;
  
  late final EngineCreateDart engineCreate;
  late final EngineDestroyDart engineDestroy;
  late final ModelLoadDart modelLoad;
  late final ModelUnloadDart modelUnload;
  late final FrameAcquireDart frameAcquire;
  late final FrameReleaseDart frameRelease;
  late final FrameGetDataDart frameGetData;
  late final FrameSubmitDart frameSubmit;
  late final JobCancelAllDart jobCancelAll;
  late final GetQueueDepthDart getQueueDepth;
  late final GetLastErrorDart getLastError;
  
  // Phase 5: RIFE functions
  late final QueueInvalidateDart queueInvalidate;
  late final SetRifeConfigDart setRifeConfig;
  late final SetAudioTimestampOffsetDart setAudioTimestampOffset;

  // Phase 6: Audio functions
  late final SetAudioDspConfigDart setAudioDspConfig;
  late final SetAudioAiConfigDart setAudioAiConfig;
  late final BypassAudioEnhancementDart bypassAudioEnhancement;

  // Phase 8: Advanced Features
  late final GenerateSubtitlesDart generateSubtitles;
  late final SetDepthConfigDart setDepthConfig;
  late final CanEnablePipelineDart canEnablePipeline;

  EPlayerEngineBindings() {
    if (Platform.isAndroid) {
      _lib = ffi.DynamicLibrary.open('libeplayer_engine.so');
    } else if (Platform.isWindows) {
      _lib = ffi.DynamicLibrary.open('eplayer_engine.dll');
    } else if (Platform.isIOS || Platform.isMacOS) {
      _lib = ffi.DynamicLibrary.process();
    } else if (Platform.isLinux) {
      _lib = ffi.DynamicLibrary.open('libeplayer_engine.so');
    } else {
      throw UnsupportedError('Unsupported platform');
    }
    _bind();
  }

  void _bind() {
    engineCreate = _lib.lookupFunction<EngineCreateNative, EngineCreateDart>('eplayer_engine_create');
    engineDestroy = _lib.lookupFunction<EngineDestroyNative, EngineDestroyDart>('eplayer_engine_destroy');
    modelLoad = _lib.lookupFunction<ModelLoadNative, ModelLoadDart>('eplayer_model_load');
    modelUnload = _lib.lookupFunction<ModelUnloadNative, ModelUnloadDart>('eplayer_model_unload');
    frameAcquire = _lib.lookupFunction<FrameAcquireNative, FrameAcquireDart>('eplayer_frame_acquire');
    frameRelease = _lib.lookupFunction<FrameReleaseNative, FrameReleaseDart>('eplayer_frame_release');
    frameGetData = _lib.lookupFunction<FrameGetDataNative, FrameGetDataDart>('eplayer_frame_get_data');
    frameSubmit = _lib.lookupFunction<FrameSubmitNative, FrameSubmitDart>('eplayer_frame_submit');
    jobCancelAll = _lib.lookupFunction<JobCancelAllNative, JobCancelAllDart>('eplayer_job_cancel_all');
    getQueueDepth = _lib.lookupFunction<GetQueueDepthNative, GetQueueDepthDart>('eplayer_get_queue_depth');
    getLastError = _lib.lookupFunction<GetLastErrorNative, GetLastErrorDart>('eplayer_get_last_error');
    
    // Phase 5: RIFE functions
    queueInvalidate = _lib.lookupFunction<QueueInvalidateNative, QueueInvalidateDart>('eplayer_queue_invalidate');
    setRifeConfig = _lib.lookupFunction<SetRifeConfigNative, SetRifeConfigDart>('eplayer_set_rife_config');
    setAudioTimestampOffset = _lib.lookupFunction<SetAudioTimestampOffsetNative, SetAudioTimestampOffsetDart>('eplayer_set_audio_timestamp_offset');

    // Phase 6: Audio functions
    setAudioDspConfig = _lib.lookupFunction<SetAudioDspConfigNative, SetAudioDspConfigDart>('eplayer_set_audio_dsp_config');
    setAudioAiConfig = _lib.lookupFunction<SetAudioAiConfigNative, SetAudioAiConfigDart>('eplayer_set_audio_ai_config');
    bypassAudioEnhancement = _lib.lookupFunction<BypassAudioEnhancementNative, BypassAudioEnhancementDart>('eplayer_bypass_audio_enhancement');

    // Phase 8: Advanced Features
    generateSubtitles = _lib.lookupFunction<GenerateSubtitlesNative, GenerateSubtitlesDart>('eplayer_generate_subtitles');
    setDepthConfig = _lib.lookupFunction<SetDepthConfigNative, SetDepthConfigDart>('eplayer_set_depth_config');
    canEnablePipeline = _lib.lookupFunction<CanEnablePipelineNative, CanEnablePipelineDart>('eplayer_can_enable_pipeline');
  }
}
