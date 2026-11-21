import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/web_remote/data/qr_code_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QrCodeGenerator Tests (Pure Dart)', () {
    test('1. Generates 21x21 matrix for short string (Version 1)', () {
      final matrix = QrCodeGenerator.generateMatrix('TEST');
      expect(matrix.length, equals(21));
      expect(matrix[0].length, equals(21));

      // Check top-left finder pattern center (row 3, col 3 is solid black)
      expect(matrix[3][3], isTrue);
      // Check top-left finder pattern corner (0,0 is solid black)
      expect(matrix[0][0], isTrue);
      // Check separator space inside finder (row 1, col 1 is white)
      expect(matrix[1][1], isFalse);
    });

    test('2. Generates 25x25 matrix for typical Wi-Fi URL (Version 2)', () {
      const url = 'http://192.168.1.15:8080';
      final matrix = QrCodeGenerator.generateMatrix(url);
      expect(matrix.length, equals(25));
      expect(matrix[0].length, equals(25));

      // Check bottom-left finder corner (24, 0 is solid black)
      expect(matrix[24][0], isTrue);
      // Check top-right finder corner (0, 24 is solid black)
      expect(matrix[0][24], isTrue);

      // Check timing pattern (row 6 alternates)
      for (int c = 8; c < 16; c++) {
        expect(matrix[6][c], equals(c % 2 == 0));
      }
    });

    test('3. Alignment pattern exists in Version 2 at (18, 18)', () {
      const url = 'http://192.168.1.100:8080';
      final matrix = QrCodeGenerator.generateMatrix(url, forcedVersion: 2);
      expect(matrix.length, equals(25));

      // Alignment pattern center at (18, 18) must be black
      expect(matrix[18][18], isTrue);
      // Immediate ring around center (17, 18) must be white
      expect(matrix[17][18], isFalse);
      expect(matrix[19][18], isFalse);
      // Outer border (16, 18) must be black
      expect(matrix[16][18], isTrue);
    });

    test('4. QrCodePainter renders matrix cleanly on Canvas', () {
      final matrix = QrCodeGenerator.generateMatrix('http://localhost:8080');
      final painter = QrCodePainter(
        matrix: matrix,
        moduleColor: const Color(0xFF00E5FF),
        backgroundColor: const Color(0xFF0D1728),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(200, 200));
      final picture = recorder.endRecording();

      expect(picture, isNotNull);
    });
  });
}
