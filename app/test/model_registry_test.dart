import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/model_registry.dart';

void main() {
  group('ModelRegistry Tests', () {
    late ModelRegistry registry;

    setUp(() {
      registry = ModelRegistry();
    });

    test('Registry initializes empty', () {
      expect(registry.getModel('realesr-general-mobile'), isNull);
    });

    test('Adding and retrieving a valid model metadata via loadPlaceholders', () {
      registry.loadPlaceholders();
      
      final model = registry.getModel('realesr-general-mobile');
      expect(model, isNotNull);
      expect(model!.id, 'realesr-general-mobile');
      expect(model.outputScale, 2);
    });

    test('Model checksum validation', () {
      final fakeBytes = [0, 1, 2, 3];
      // We expect the sha256 of [0, 1, 2, 3] to not match some dummy
      final isValid = registry.validateChecksum(fakeBytes, 'dummy_hash');
      expect(isValid, isFalse);
    });
  });
}
