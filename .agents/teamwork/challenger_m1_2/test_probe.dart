import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/player/domain/decoder_models.dart';
import 'package:app/features/player/domain/decoder_pipeline_service.dart';

void main() {
  test('Probe test from challenger directory', () {
    expect(DecoderMode.auto.label, 'Auto');
  });
}
