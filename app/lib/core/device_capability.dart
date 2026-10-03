import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

enum CapabilityTier { legacy, mainstream, highPerformance }

class DeviceCapabilityProfile {
  final String osVersion;
  final int apiLevel;
  final String architecture;
  final int ramBytes;
  final int storageBytes;
  final bool gpuFeatures;
  final bool neuralAcceleration;
  final bool codecSupport;
  final String thermalStatus;
  
  final int maxRecommendedLiveResolution;
  final int maxRecommendedLiveFps;
  
  final List<String> supportedModels;
  final List<String> supportedExecutionProviders;

  const DeviceCapabilityProfile({
    required this.osVersion,
    required this.apiLevel,
    required this.architecture,
    required this.ramBytes,
    required this.storageBytes,
    required this.gpuFeatures,
    required this.neuralAcceleration,
    required this.codecSupport,
    required this.thermalStatus,
    required this.maxRecommendedLiveResolution,
    required this.maxRecommendedLiveFps,
    required this.supportedModels,
    required this.supportedExecutionProviders,
  });

  CapabilityTier get currentTier {
    if (ramBytes < 4 * 1024 * 1024 * 1024 || !gpuFeatures) {
      return CapabilityTier.legacy; // Tier A
    } else if (ramBytes < 8 * 1024 * 1024 * 1024 || !neuralAcceleration) {
      return CapabilityTier.mainstream; // Tier B
    } else {
      return CapabilityTier.highPerformance; // Tier C
    }
  }
}

class CapabilityDetector {
  static Future<DeviceCapabilityProfile> discover() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String osVersion = "Unknown";
    int apiLevel = 0;
    String architecture = "Unknown";
    
    // Placeholder values for hardware detection (would typically require native FFI or MethodChannels)
    int ramBytes = 4 * 1024 * 1024 * 1024; // 4GB default
    int storageBytes = 16 * 1024 * 1024 * 1024; // 16GB free default
    bool gpuFeatures = true;
    bool neuralAcceleration = false;
    bool codecSupport = true;
    String thermalStatus = "nominal";

    if (Platform.isAndroid) {
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      osVersion = androidInfo.version.release;
      apiLevel = androidInfo.version.sdkInt;
      architecture = androidInfo.supportedAbis.isNotEmpty ? androidInfo.supportedAbis.first : "Unknown";
    } else if (Platform.isIOS) {
      final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      osVersion = iosInfo.systemVersion;
      final majorVersionStr = osVersion.split('.').first;
      apiLevel = int.tryParse(majorVersionStr) ?? 0;
      architecture = "arm64"; // Defaulting as iOS requires arm64
    }

    return DeviceCapabilityProfile(
      osVersion: osVersion,
      apiLevel: apiLevel,
      architecture: architecture,
      ramBytes: ramBytes,
      storageBytes: storageBytes,
      gpuFeatures: gpuFeatures,
      neuralAcceleration: neuralAcceleration,
      codecSupport: codecSupport,
      thermalStatus: thermalStatus,
      maxRecommendedLiveResolution: 1080, // Default 1080p
      maxRecommendedLiveFps: 30, // Default 30 FPS
      supportedModels: [], // Empty initially
      supportedExecutionProviders: ['cpu', 'xnnpack'], // Baseline
    );
  }
}
