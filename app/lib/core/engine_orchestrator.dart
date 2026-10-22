import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'ffi/engine_bindings.dart';

class NativeEngineOrchestrator {
  EPlayerEngineBindings? _bindings;
  Pointer<EPEngineHandle>? _engine;

  NativeEngineOrchestrator() {
    try {
      _bindings = EPlayerEngineBindings();
    } catch (e) {
      debugPrint("Warning: Native AI engine DLL not found. AI features will be disabled. Error: $e");
    }
  }

  bool get isLoaded => _engine != null;

  void initialize() {
    if (_bindings == null || _engine != null) return;
    try {
      _engine = _bindings!.engineCreate();
    } catch (e) {
      debugPrint("Error creating engine: $e");
    }
  }

  void shutdown() {
    if (_bindings != null && _engine != null) {
      _bindings!.engineDestroy(_engine!);
      _engine = null;
    }
  }

  Pointer<EPModelHandle>? loadModel(String modelPath, String provider, int numThreads) {
    if (_engine == null) return null;

    final pathPtr = modelPath.toNativeUtf8();
    final providerPtr = provider.toNativeUtf8();

    final model = _bindings!.modelLoad(_engine!, pathPtr, providerPtr, numThreads);

    calloc.free(pathPtr);
    calloc.free(providerPtr);

    if (model == nullptr) {
      final errorPtr = _bindings!.getLastError(_engine!);
      String errorMsg = errorPtr != nullptr ? errorPtr.toDartString() : "Unknown native error";

      // Phase 9C: Reliability - Model load failure / corrupt weights handling
      if (errorMsg.contains("corrupt") || errorMsg.contains("invalid model")) {
        throw Exception(
          "CRITICAL: AI Model '$modelPath' is corrupt or incomplete. Please re-download the model package.",
        );
      } else if (errorMsg.contains("memory") || errorMsg.contains("alloc")) {
        throw Exception(
          "CRITICAL: Insufficient memory to load '$modelPath'. Please close other applications.",
        );
      }

      throw Exception("Failed to load model '$modelPath': $errorMsg");
    }

    return model;
  }

  void unloadModel(Pointer<EPModelHandle> model) {
    if (_engine == null || model == nullptr) return;
    _bindings!.modelUnload(_engine!, model);
  }

  void cancelAllJobs() {
    if (_engine == null) return;
    _bindings!.jobCancelAll(_engine!);
  }

  int getQueueDepth() {
    if (_engine == null) return 0;
    return _bindings!.getQueueDepth(_engine!);
  }

  // --- Phase 12 & 13: Tiled Inference & Offline AI Export Execution ---

  int processExportChunk({
    Pointer<EPModelHandle>? model,
    required String sourcePath,
    required String tempOutputPath,
    required int targetWidth,
    required int targetHeight,
    required int targetFps,
    required int chunkIndex,
    required int totalChunks,
  }) {
    if (_engine == null || _bindings == null) return -1;
    final fn = _bindings!.exportProcessChunk;
    if (fn == null) return -1;

    final srcPtr = sourcePath.toNativeUtf8();
    final tmpPtr = tempOutputPath.toNativeUtf8();
    try {
      return fn(
        _engine!,
        model ?? nullptr,
        srcPtr,
        tmpPtr,
        targetWidth,
        targetHeight,
        targetFps,
        chunkIndex,
        totalChunks,
      );
    } finally {
      calloc.free(srcPtr);
      calloc.free(tmpPtr);
    }
  }

  bool validateExportContainer(String filePath) {
    if (_engine == null || _bindings == null) return false;
    final fn = _bindings!.validateExportContainer;
    if (fn == null) return false;

    final pathPtr = filePath.toNativeUtf8();
    try {
      return fn(_engine!, pathPtr);
    } finally {
      calloc.free(pathPtr);
    }
  }

  // --- Phase 5: RIFE Frame Interpolation Controls ---

  void setRifeConfig(int targetFps, bool enableSceneCutDetection) {
    if (_engine == null) return;
    _bindings!.setRifeConfig(_engine!, targetFps, enableSceneCutDetection);
  }

  void invalidateQueue() {
    if (_engine == null) return;
    _bindings!.queueInvalidate(_engine!);
  }

  void setAudioTimestampOffset(int offsetMs) {
    if (_engine == null) return;
    _bindings!.setAudioTimestampOffset(_engine!, offsetMs);
  }

  // --- Phase 6: Audio Enhancement ---

  void setAudioDspConfig({
    bool enableEq = false,
    bool enableNormalization = false,
    bool enableCompressor = false,
    bool enableDialogueBoost = false,
    bool enableNightMode = false,
  }) {
    if (_engine == null) return;
    _bindings!.setAudioDspConfig(
      _engine!,
      enableEq,
      enableNormalization,
      enableCompressor,
      enableDialogueBoost,
      enableNightMode,
    );
  }

  void setAudioAiConfig(bool enableRnnoise, double strength) {
    if (_engine == null) return;
    _bindings!.setAudioAiConfig(_engine!, enableRnnoise, strength);
  }

  void bypassAudioEnhancement(bool bypass) {
    if (_engine == null) return;
    _bindings!.bypassAudioEnhancement(_engine!, bypass);
  }

  // --- Phase 8: Advanced Features ---

  void generateSubtitles(String audioPath, String outputSrtPath) {
    if (_engine == null) return;
    final audioPtr = audioPath.toNativeUtf8();
    final outPtr = outputSrtPath.toNativeUtf8();
    _bindings!.generateSubtitles(_engine!, audioPtr, outPtr);
    calloc.free(audioPtr);
    calloc.free(outPtr);
  }

  void setDepthConfig(bool enableSbs, double depthStrength, double convergence) {
    if (_engine == null) return;
    _bindings!.setDepthConfig(_engine!, enableSbs, depthStrength, convergence);
  }

  bool canEnablePipeline({
    bool needsSpatial = false,
    bool needsTemporal = false,
    bool needsAudio = false,
    bool needsDepth = false,
  }) {
    if (_engine == null) return false;
    return _bindings!.canEnablePipeline(
      _engine!,
      needsSpatial,
      needsTemporal,
      needsAudio,
      needsDepth,
    );
  }
}
