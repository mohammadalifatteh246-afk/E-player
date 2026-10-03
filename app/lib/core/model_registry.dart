import 'package:crypto/crypto.dart';

class ModelMetadata {
  final String id;
  final String version;
  final String purpose;
  final List<int> inputShape; // e.g. [1, 3, 224, 224]
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

  void loadPlaceholders() {
    // Placeholder entries as per Phase 0C
    final placeholder = ModelMetadata(
      id: "realesr-general-mobile",
      version: "1.0.0",
      purpose: "spatial_enhancement",
      inputShape: [-1, 3, -1, -1],
      outputScale: 2,
      supportedProviders: ["cpu", "xnnpack"],
      quantization: "fp16",
      expectedMemoryBytes: 150 * 1024 * 1024,
      minimumCapabilityTier: "mainstream",
      license: "MIT",
      checksum: "00000000000000000000000000000000",
      enabledFeatures: ["live", "export"],
    );
    _registry[placeholder.id] = placeholder;
  }

  bool validateChecksum(List<int> fileBytes, String expectedChecksum) {
    final digest = sha256.convert(fileBytes);
    return digest.toString() == expectedChecksum;
  }
  
  ModelMetadata? getModel(String id) {
    return _registry[id];
  }
}
