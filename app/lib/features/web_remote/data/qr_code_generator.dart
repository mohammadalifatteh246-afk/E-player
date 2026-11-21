import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Pure Dart QR Code Generator (ISO/IEC 18004 Model 2)
/// Designed specifically for encoding local Wi-Fi URLs and remote endpoints
/// without requiring any native C++ or external dependencies.
class QrCodeGenerator {
  /// Generates a 2D boolean grid (true = module/black, false = empty/white)
  /// for the provided input string [data].
  static List<List<bool>> generateMatrix(String data, {int? forcedVersion}) {
    final bytes = Uint8List.fromList(data.codeUnits);
    final version = forcedVersion ?? _determineVersion(bytes.length);
    final size = 17 + 4 * version;

    // Grid initialized with null/false
    final matrix = List.generate(size, (_) => List.generate(size, (_) => false));
    final reserved = List.generate(size, (_) => List.generate(size, (_) => false));

    // 1. Add Finder Patterns (7x7) + Separators
    _addFinderPattern(matrix, reserved, 0, 0, size);
    _addFinderPattern(matrix, reserved, size - 7, 0, size);
    _addFinderPattern(matrix, reserved, 0, size - 7, size);

    // 2. Add Alignment Pattern for Version >= 2
    if (version >= 2) {
      final alignPos = _getAlignmentPatternPosition(version);
      _addAlignmentPattern(matrix, reserved, alignPos, alignPos);
    }

    // 3. Add Timing Patterns
    for (int i = 8; i < size - 8; i++) {
      final bit = (i % 2 == 0);
      matrix[6][i] = bit;
      reserved[6][i] = true;
      matrix[i][6] = bit;
      reserved[i][6] = true;
    }

    // 4. Dark Module
    matrix[size - 8][8] = true;
    reserved[size - 8][8] = true;

    // 5. Reserve Format Info areas (around finders)
    _reserveFormatAreas(reserved, size);

    // 6. Encode Data with Byte Mode & Reed-Solomon EC
    final encodedBits = _encodeData(bytes, version);

    // 7. Place Data in zigzag order
    _placeDataBits(matrix, reserved, encodedBits, size);

    // 8. Apply Mask Pattern 0: (row + col) % 2 == 0
    _applyMask(matrix, reserved, size);

    // 9. Write Format Information (Error Correction Level L, Mask 0)
    _writeFormatInformation(matrix, size);

    return matrix;
  }

  static int _determineVersion(int byteCount) {
    if (byteCount <= 17) return 1;
    if (byteCount <= 32) return 2;
    if (byteCount <= 53) return 3;
    return 4; // up to 78 bytes in Low EC
  }

  static int _getAlignmentPatternPosition(int version) {
    switch (version) {
      case 2:
        return 18;
      case 3:
        return 22;
      case 4:
        return 26;
      default:
        return 18;
    }
  }

  static void _addFinderPattern(
    List<List<bool>> matrix,
    List<List<bool>> reserved,
    int r,
    int c,
    int size,
  ) {
    // 7x7 finder pattern + 1 module border
    for (int y = -1; y <= 7; y++) {
      for (int x = -1; x <= 7; x++) {
        final row = r + y;
        final col = c + x;
        if (row >= 0 && row < size && col >= 0 && col < size) {
          reserved[row][col] = true;
          if (y >= 0 && y <= 6 && x >= 0 && x <= 6) {
            final isOuter = (y == 0 || y == 6 || x == 0 || x == 6);
            final isInner = (y >= 2 && y <= 4 && x >= 2 && x <= 4);
            matrix[row][col] = isOuter || isInner;
          } else {
            matrix[row][col] = false; // separator
          }
        }
      }
    }
  }

  static void _addAlignmentPattern(
    List<List<bool>> matrix,
    List<List<bool>> reserved,
    int centerR,
    int centerC,
  ) {
    for (int y = -2; y <= 2; y++) {
      for (int x = -2; x <= 2; x++) {
        final row = centerR + y;
        final col = centerC + x;
        if (!reserved[row][col]) {
          reserved[row][col] = true;
          final isOuter = (y.abs() == 2 || x.abs() == 2);
          final isCenter = (y == 0 && x == 0);
          matrix[row][col] = isOuter || isCenter;
        }
      }
    }
  }

  static void _reserveFormatAreas(List<List<bool>> reserved, int size) {
    for (int i = 0; i <= 8; i++) {
      reserved[8][i] = true;
      reserved[i][8] = true;
    }
    for (int i = size - 8; i < size; i++) {
      reserved[8][i] = true;
      reserved[i][8] = true;
    }
  }

  static List<bool> _encodeData(Uint8List data, int version) {
    final bits = <bool>[];

    // Mode: Byte Mode (0100)
    bits.addAll([false, true, false, false]);

    // Character Count (8 bits for version 1-4)
    final len = data.length;
    for (int i = 7; i >= 0; i--) {
      bits.add(((len >> i) & 1) == 1);
    }

    // Data Bytes
    for (final b in data) {
      for (int i = 7; i >= 0; i--) {
        bits.add(((b >> i) & 1) == 1);
      }
    }

    // Capacity in bytes for Low EC
    final totalCapacityBytes = _getTotalDataCapacity(version);
    final totalCapacityBits = totalCapacityBytes * 8;

    // Terminator (up to 4 zeros)
    final termLen = (totalCapacityBits - bits.length).clamp(0, 4);
    for (int i = 0; i < termLen; i++) {
      bits.add(false);
    }

    // Pad to byte boundary
    while (bits.length % 8 != 0) {
      bits.add(false);
    }

    // Pad bytes alternating 0xEC (11101100) and 0x11 (00010001)
    final dataBytes = <int>[];
    for (int i = 0; i < bits.length; i += 8) {
      int b = 0;
      for (int j = 0; j < 8; j++) {
        if (bits[i + j]) b |= (1 << (7 - j));
      }
      dataBytes.add(b);
    }

    bool padAlt = true;
    while (dataBytes.length < totalCapacityBytes) {
      dataBytes.add(padAlt ? 0xEC : 0x11);
      padAlt = !padAlt;
    }

    // Generate Reed-Solomon Error Correction Codewords
    final ecBytesCount = _getEcBytesCount(version);
    final ecCodewords = _generateReedSolomon(dataBytes, ecBytesCount);

    // Final bitstream: data bytes + EC codewords
    final finalBytes = [...dataBytes, ...ecCodewords];
    final resultBits = <bool>[];
    for (final b in finalBytes) {
      for (int i = 7; i >= 0; i--) {
        resultBits.add(((b >> i) & 1) == 1);
      }
    }

    return resultBits;
  }

  static int _getTotalDataCapacity(int version) {
    switch (version) {
      case 1:
        return 19;
      case 2:
        return 34;
      case 3:
        return 55;
      case 4:
        return 80;
      default:
        return 34;
    }
  }

  static int _getEcBytesCount(int version) {
    switch (version) {
      case 1:
        return 7;
      case 2:
        return 10;
      case 3:
        return 15;
      case 4:
        return 20;
      default:
        return 10;
    }
  }

  static List<int> _generateReedSolomon(List<int> data, int ecCount) {
    // Standard GF(256) tables with primitive polynomial 0x11D (285)
    final gfExp = List<int>.filled(512, 0);
    final gfLog = List<int>.filled(256, 0);

    int val = 1;
    for (int i = 0; i < 255; i++) {
      gfExp[i] = val;
      gfExp[i + 255] = val;
      gfLog[val] = i;
      val <<= 1;
      if (val >= 256) val ^= 0x11D;
    }

    int gfMul(int x, int y) {
      if (x == 0 || y == 0) return 0;
      return gfExp[gfLog[x] + gfLog[y]];
    }

    // Compute generator polynomial
    var gen = [1];
    for (int i = 0; i < ecCount; i++) {
      final root = gfExp[i];
      final nextGen = List<int>.filled(gen.length + 1, 0);
      for (int j = 0; j < gen.length; j++) {
        nextGen[j] ^= gfMul(gen[j], root);
        nextGen[j + 1] ^= gen[j];
      }
      gen = nextGen;
    }

    // Remainder division
    final res = List<int>.filled(ecCount, 0);
    for (final b in data) {
      final factor = b ^ res[0];
      for (int i = 0; i < ecCount - 1; i++) {
        res[i] = res[i + 1] ^ gfMul(gen[ecCount - 1 - i], factor);
      }
      res[ecCount - 1] = gfMul(gen[0], factor);
    }

    return res.reversed.toList();
  }

  static void _placeDataBits(
    List<List<bool>> matrix,
    List<List<bool>> reserved,
    List<bool> bits,
    int size,
  ) {
    int bitIndex = 0;
    int col = size - 1;
    bool goingUp = true;

    while (col > 0) {
      if (col == 6) col--; // skip vertical timing column

      final rows = goingUp
          ? List.generate(size, (i) => size - 1 - i)
          : List.generate(size, (i) => i);

      for (final row in rows) {
        for (int c = col; c >= col - 1; c--) {
          if (!reserved[row][c]) {
            if (bitIndex < bits.length) {
              matrix[row][c] = bits[bitIndex++];
            } else {
              matrix[row][c] = false;
            }
          }
        }
      }

      goingUp = !goingUp;
      col -= 2;
    }
  }

  static void _applyMask(
    List<List<bool>> matrix,
    List<List<bool>> reserved,
    int size,
  ) {
    // Mask Pattern 0: (row + col) % 2 == 0
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (!reserved[r][c] && (r + c) % 2 == 0) {
          matrix[r][c] = !matrix[r][c];
        }
      }
    }
  }

  static void _writeFormatInformation(List<List<bool>> matrix, int size) {
    // Format information for EC Level L (01) and Mask Pattern 0 (000)
    // 15-bit sequence with BCH code and mask 0x5412: 0x77C4 (111011111000100)
    const formatBits = [
      true, true, true, false, true, true, true, true,
      true, false, false, false, true, false, false,
    ];

    // Around top-left finder
    final coords1 = [
      (8, 0), (8, 1), (8, 2), (8, 3), (8, 4), (8, 5), (8, 7), (8, 8),
      (7, 8), (5, 8), (4, 8), (3, 8), (2, 8), (1, 8), (0, 8),
    ];
    for (int i = 0; i < 15; i++) {
      final (r, c) = coords1[i];
      matrix[r][c] = formatBits[i];
    }

    // Around top-right and bottom-left finders
    for (int i = 0; i < 7; i++) {
      matrix[size - 1 - i][8] = formatBits[i];
    }
    for (int i = 0; i < 8; i++) {
      matrix[8][size - 8 + i] = formatBits[7 + i];
    }
  }
}

/// CustomPainter that renders the QR Code matrix on a Flutter canvas
/// with neon Cyberpunk styling matching E-Player's aesthetic.
class QrCodePainter extends CustomPainter {
  final List<List<bool>> matrix;
  final Color moduleColor;
  final Color backgroundColor;
  final double padding;

  const QrCodePainter({
    required this.matrix,
    this.moduleColor = const Color(0xFF00E5FF),
    this.backgroundColor = const Color(0xFF0D1728),
    this.padding = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final matrixSize = matrix.length;
    if (matrixSize == 0) return;

    // Draw background
    final bgPaint = Paint()..color = backgroundColor;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(12),
    );
    canvas.drawRRect(rrect, bgPaint);

    final availableWidth = size.width - (padding * 2);
    final availableHeight = size.height - (padding * 2);
    final dimension = availableWidth < availableHeight ? availableWidth : availableHeight;
    final moduleSize = dimension / matrixSize;

    final offsetX = (size.width - dimension) / 2;
    final offsetY = (size.height - dimension) / 2;

    final modulePaint = Paint()
      ..color = moduleColor
      ..style = PaintingStyle.fill;

    for (int r = 0; r < matrixSize; r++) {
      for (int c = 0; c < matrixSize; c++) {
        if (matrix[r][c]) {
          final rect = Rect.fromLTWH(
            offsetX + c * moduleSize,
            offsetY + r * moduleSize,
            moduleSize + 0.3, // slight overlap to avoid subpixel gaps
            moduleSize + 0.3,
          );
          canvas.drawRect(rect, modulePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant QrCodePainter oldDelegate) {
    return oldDelegate.matrix != matrix ||
        oldDelegate.moduleColor != moduleColor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
