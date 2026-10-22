import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/features/settings/domain/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider Unit Tests', () {
    late SettingsProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'hwAcceleration': true,
        'decodingMode': 'HW+',
        'aspectRatio': 'Fit',
        'playbackSpeed': '1.0x',
        'gestureControls': true,
        'zeroCopyGpu': true,
        'dynamicResSwitching': true,
        'defaultAiModel': 'Real-ESRGAN x4 Plus',
        'rifeDefault': false,
        'tensorPrecision': 'FP16 Compute',
        'vramLimit': '4.0 GB',
        'defaultAudioPreset': 'Flat',
        'speechClarity': true,
        'spatialVirtualizer': false,
        'audioOutputFormat': 'Stereo (2.0)',
        'fontSize': 'Medium',
        'textColor': 'White',
        'outline': '2px',
        'subtitleLanguage': 'English [en]',
        'autoEncoding': true,
        'dualPassOutline': true,
        'lowLatencyRtsp': true,
        'networkBufferSize': '32 MB',
        'decoyModeEnabled': true,
        'autoLockVault': true,
        'biometricsEnabled': true,
      });

      provider = SettingsProvider();
      // Allow async _loadSettings to complete
      await Future.delayed(const Duration(milliseconds: 50));
    });

    test('Initial settings match expected defaults', () {
      expect(provider.hwAcceleration, isTrue);
      expect(provider.decodingMode, 'HW+');
      expect(provider.aspectRatio, 'Fit');
      expect(provider.playbackSpeed, '1.0x');
      expect(provider.gestureControls, isTrue);
      expect(provider.zeroCopyGpu, isTrue);
      expect(provider.dynamicResSwitching, isTrue);
      expect(provider.defaultAiModel, 'Real-ESRGAN x4 Plus');
      expect(provider.rifeDefault, isFalse);
      expect(provider.tensorPrecision, 'FP16 Compute');
      expect(provider.vramLimit, '4.0 GB');
      expect(provider.defaultAudioPreset, 'Flat');
      expect(provider.speechClarity, isTrue);
      expect(provider.spatialVirtualizer, isFalse);
      expect(provider.audioOutputFormat, 'Stereo (2.0)');
      expect(provider.subtitleLanguage, 'English [en]');
      expect(provider.lowLatencyRtsp, isTrue);
      expect(provider.networkBufferSize, '32 MB');
      expect(provider.decoyModeEnabled, isTrue);
      expect(provider.autoLockVault, isTrue);
      expect(provider.biometricsEnabled, isTrue);
    });

    test('Setters update in-memory state and notify listeners', () async {
      await provider.setDecodingMode('HW');
      expect(provider.decodingMode, 'HW');

      await provider.setAspectRatio('16:9');
      expect(provider.aspectRatio, '16:9');

      await provider.setDefaultAiModel('Anime4K v4.0');
      expect(provider.defaultAiModel, 'Anime4K v4.0');

      await provider.setRifeDefault(true);
      expect(provider.rifeDefault, isTrue);

      await provider.setSpatialVirtualizer(true);
      expect(provider.spatialVirtualizer, isTrue);

      await provider.setNetworkBufferSize('64 MB');
      expect(provider.networkBufferSize, '64 MB');
    });

    test('Clear cache methods reset cache counts', () async {
      expect(provider.shaderCacheMb, greaterThan(0));
      expect(provider.aiTempCacheMb, greaterThan(0));

      await provider.clearShaderCache();
      expect(provider.shaderCacheMb, 0.0);

      await provider.clearAiTempCache();
      expect(provider.aiTempCacheMb, 0.0);
    });

    test('Reset to defaults restores initial settings', () async {
      await provider.setDecodingMode('SW');
      await provider.setRifeDefault(true);
      expect(provider.decodingMode, 'SW');
      expect(provider.rifeDefault, isTrue);

      await provider.resetToDefaults();
      expect(provider.decodingMode, 'HW+');
      expect(provider.rifeDefault, isFalse);
      expect(provider.hwAcceleration, isTrue);
    });
  });
}
