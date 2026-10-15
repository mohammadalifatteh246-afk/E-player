import 'package:crypto/crypto.dart';

class ModelMetadata {
  final String id;
  final String version;
  final String purpose;
  final List<int> inputShape; // e.g. [1, 3, 256, 256]
  final int outputScale;
  final List<String> supportedProviders;
  final String quantization; // e.g. 'fp16', 'int8', 'fp32'
  final int expectedMemoryBytes;
  final String minimumCapabilityTier;
  final String license;
  final String checksum;
  final List<String> enabledFeatures;

  const ModelMetadata({
    required this.id,
    required this.version,
    required this.purpose,
    required this.inputShape,
    required this.outputScale,
    required this.supportedProviders,
    required this.quantization,
    required this.expectedMemoryBytes,
    required this.minimumCapabilityTier,
    required this.license,
    required this.checksum,
    required this.enabledFeatures,
  });

  factory ModelMetadata.fromJson(Map<String, dynamic> json) {
    return ModelMetadata(
      id: json['id'] as String,
      version: json['version'] as String,
      purpose: json['purpose'] as String,
      inputShape: List<int>.from(json['inputShape'] ?? []),
      outputScale: json['outputScale'] as int? ?? 1,
      supportedProviders: List<String>.from(json['supportedProviders'] ?? []),
      quantization: json['quantization'] as String,
      expectedMemoryBytes: json['expectedMemoryBytes'] as int,
      minimumCapabilityTier: json['minimumCapabilityTier'] as String,
      license: json['license'] as String,
      checksum: json['checksum'] as String,
      enabledFeatures: List<String>.from(json['enabledFeatures'] ?? []),
    );
  }
}

class ModelRegistry {
  final Map<String, ModelMetadata> _registry = {};

  List<ModelMetadata> get allModels => _registry.values.toList();

  void loadPlaceholders() {
    // Phase 0C & Phase 12.3: Registered ONNX Mobile Model Manifests
    final models = [
      const ModelMetadata(
        id: "realesr-general-mobile",
        version: "1.0.0",
        purpose: "spatial_enhancement",
        inputShape: [-1, 3, -1, -1],
        outputScale: 2,
        supportedProviders: ["cpu", "xnnpack", "nnapi", "coreml"],
        quantization: "fp16",
        expectedMemoryBytes: 150 * 1024 * 1024,
        minimumCapabilityTier: "mainstream",
        license: "BSD-3-Clause",
        checksum: "00000000000000000000000000000000",
        enabledFeatures: ["live", "export"],
      ),
      const ModelMetadata(
        id: "realesrgan-anime-fp16",
        version: "1.0.0",
        purpose: "spatial_enhancement_anime",
        inputShape: [1, 3, 256, 256],
        outputScale: 2,
        supportedProviders: ["cpu", "xnnpack", "nnapi", "coreml"],
        quantization: "fp16",
        expectedMemoryBytes: 96 * 1024 * 1024,
        minimumCapabilityTier: "mainstream",
        license: "BSD-3-Clause",
        checksum: "c21f969b5f03d33d43e04f8f136e7682",
        enabledFeatures: ["live", "export"],
      ),
      const ModelMetadata(
        id: "rife-v4.6-mobile",
        version: "4.6.0",
        purpose: "temporal_interpolation",
        inputShape: [1, 6, 256, 256],
        outputScale: 1,
        supportedProviders: ["cpu", "xnnpack", "coreml"],
        quantization: "fp16",
        expectedMemoryBytes: 180 * 1024 * 1024,
        minimumCapabilityTier: "mainstream",
        license: "MIT",
        checksum: "e4d909c290d0fb1ca068ffaddf22cbd0",
        enabledFeatures: ["live", "export"],
      ),
      const ModelMetadata(
        id: "rnnoise-speech-mobile",
        version: "1.2.0",
        purpose: "audio_denoise",
        inputShape: [1, 42],
        outputScale: 1,
        supportedProviders: ["cpu", "xnnpack"],
        quantization: "fp32",
        expectedMemoryBytes: 16 * 1024 * 1024,
        minimumCapabilityTier: "legacy",
        license: "BSD-3-Clause",
        checksum: "9e107d9d372bb6826bd81d3542a419d6",
        enabledFeatures: ["live", "export"],
      ),
      const ModelMetadata(
        id: "depth-anything-v2-small",
        version: "2.0.0",
        purpose: "depth_estimation_3d",
        inputShape: [1, 3, 518, 518],
        outputScale: 1,
        supportedProviders: ["cpu", "xnnpack", "coreml"],
        quantization: "fp16",
        expectedMemoryBytes: 220 * 1024 * 1024,
        minimumCapabilityTier: "highPerformance",
        license: "Apache-2.0",
        checksum: "5d41402abc4b2a76b9719d911017c592",
        enabledFeatures: ["live", "export"],
      ),
    ];

    for (final m in models) {
      _registry[m.id] = m;
    }
  }

  bool validateChecksum(List<int> fileBytes, String expectedChecksum) {
    final digest = sha256.convert(fileBytes);
    return digest.toString() == expectedChecksum;
  }

  ModelMetadata? getModel(String id) {
    return _registry[id];
  }
}
