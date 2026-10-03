import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'ffi/engine_bindings.dart';

class NativeEngineOrchestrator {
  EPlayerEngineBindings? _bindings;
  Pointer<EPEngineHandle>? _engine;

  NativeEngineOrchestrator() {
    try {
      _bindings = EPlayerEngineBindings();
    } catch (e) {
      print("Warning: Native AI engine DLL not found. AI features will be disabled. Error: $e");
    }
  }

  bool get isLoaded => _engine != null;

  void initialize() {
    if (_bindings == null || _engine != null) return;
    try {
      _engine = _bindings!.engineCreate();
    } catch (e) {
      print("Error creating engine: $e");
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
        throw Exception("CRITICAL: AI Model '$modelPath' is corrupt or incomplete. Please re-download the model package.");
      } else if (errorMsg.contains("memory") || errorMsg.contains("alloc")) {
        throw Exception("CRITICAL: Insufficient memory to load '$modelPath'. Please close other applications.");
      }
      
      throw Exception("Failed to load model '$modelPath': $errorMsg");
    }

    return model;
  }

  void unloadModel(Pointer<EPModelHandle> model) {
    if (_engine == null || model == nullptr) return;
    _bindings!.modelUnload(_engine!, model);
  }

  // Frame operations would be added here

  // --- Phase 5: RIFE Frame Interpolation Controls ---
  
  void setRifeConfig(int targetFps, bool enableSceneCutDetection) {
    if (_engine == null) return;
    _bindings!.setRifeConfig(_engine!, targetFps, enableSceneCutDetection);
  }

  void invalidateQueue() {
    // Called on video seek to prevent stale frames from interpolating into the new scene
    if (_engine == null) return;
    _bindings!.queueInvalidate(_engine!);
  }

  void setAudioTimestampOffset(int offsetMs) {
    // Phase 5C: Keep audio perfectly synchronized with RIFE interpolated frames
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
    // Phase 6A: DSP
    if (_engine == null) return;
    _bindings!.setAudioDspConfig(_engine!, enableEq, enableNormalization, enableCompressor, enableDialogueBoost, enableNightMode);
  }

  void setAudioAiConfig(bool enableRnnoise, double strength) {
    // Phase 6B: AI speech/noise
    if (_engine == null) return;
    _bindings!.setAudioAiConfig(_engine!, enableRnnoise, strength);
  }

  void bypassAudioEnhancement(bool bypass) {
    // Phase 6 Exit Criteria: instant bypass
    if (_engine == null) return;
    _bindings!.bypassAudioEnhancement(_engine!, bypass);
  }

  // --- Phase 8: Advanced Features ---

  void generateSubtitles(String audioPath, String outputSrtPath) {
    // Phase 8A: ASR
    if (_engine == null) return;
    final audioPtr = audioPath.toNativeUtf8();
    final outPtr = outputSrtPath.toNativeUtf8();
    _bindings!.generateSubtitles(_engine!, audioPtr, outPtr);
    calloc.free(audioPtr);
    calloc.free(outPtr);
  }

  void setDepthConfig(bool enableSbs, double depthStrength, double convergence) {
    // Phase 8B: 2D to 3D Depth
    if (_engine == null) return;
    _bindings!.setDepthConfig(_engine!, enableSbs, depthStrength, convergence);
  }

  bool canEnablePipeline({
    bool needsSpatial = false,
    bool needsTemporal = false,
    bool needsAudio = false,
    bool needsDepth = false,
  }) {
    // Phase 8C Exit Criteria: Capability / Thermal Gating
    if (_engine == null) return false;
    return _bindings!.canEnablePipeline(_engine!, needsSpatial, needsTemporal, needsAudio, needsDepth);
  }
}
