import 'dart:typed_data';

/// Minimal baseline JPEG encoder (4:4:4, standard quantisation and Huffman
/// tables). Used to re-encode a downscaled camera frame for the S7 safety
/// check without adding an image dependency (`dart:ui` encodes PNG only).
///
/// Adapted from the public-domain JPEG encoder by Andreas Ritter (as used in
/// jpeg-js). Luma and chroma share the standard luminance Huffman tables,
/// which is valid baseline JPEG.
final class JpegEncoder {
  JpegEncoder({int quality = 70}) {
    _initQuantTables(quality.clamp(1, 100));
    _dcTable = _huffman(_dcLumCodes, _dcLumValues);
    _acTable = _huffman(_acLumCodes, _acLumValues);
  }

  /// Encodes [rgba] (width × height × 4 bytes, row-major) to JPEG bytes.
  Uint8List encode(Uint8List rgba, int width, int height) {
    if (width <= 0 || height <= 0 || rgba.length < width * height * 4) {
      throw ArgumentError('rgba does not match $width×$height');
    }
    _out = BytesBuilder(copy: false);
    _byteNew = 0;
    _bytePos = 7;
    _writeHeaders(width, height);

    final yDu = Float64List(64), uDu = Float64List(64), vDu = Float64List(64);
    var dcY = 0, dcU = 0, dcV = 0;
    for (var by = 0; by < height; by += 8) {
      for (var bx = 0; bx < width; bx += 8) {
        for (var p = 0; p < 64; p++) {
          final x = (bx + (p & 7)).clamp(0, width - 1);
          final y = (by + (p >> 3)).clamp(0, height - 1);
          final i = (y * width + x) * 4;
          final r = rgba[i], g = rgba[i + 1], b = rgba[i + 2];
          yDu[p] = 0.299 * r + 0.587 * g + 0.114 * b - 128;
          uDu[p] = -0.16874 * r - 0.33126 * g + 0.5 * b;
          vDu[p] = 0.5 * r - 0.41869 * g - 0.08131 * b;
        }
        dcY = _processDu(yDu, _fdtblY, dcY);
        dcU = _processDu(uDu, _fdtblUv, dcU);
        dcV = _processDu(vDu, _fdtblUv, dcV);
      }
    }
    if (_bytePos != 7) {
      _writeBits((1 << (_bytePos + 1)) - 1, _bytePos + 1);
    }
    _out
      ..addByte(0xFF)
      ..addByte(0xD9);
    return _out.takeBytes();
  }

  late BytesBuilder _out;
  int _byteNew = 0;
  int _bytePos = 7;
  final _yTable = Uint8List(64);
  final _uvTable = Uint8List(64);
  final _fdtblY = Float64List(64);
  final _fdtblUv = Float64List(64);
  late List<(int, int)?> _dcTable;
  late List<(int, int)?> _acTable;
  final _du = Int32List(64);
  final _work = Float64List(64);

  void _initQuantTables(int quality) {
    final sf = quality < 50 ? 5000 ~/ quality : 200 - quality * 2;
    for (var i = 0; i < 64; i++) {
      _yTable[_zigZag[i]] = ((_yqt[i] * sf + 50) ~/ 100).clamp(1, 255);
      _uvTable[_zigZag[i]] = ((_uvqt[i] * sf + 50) ~/ 100).clamp(1, 255);
    }
    const aasf = [
      1.0,
      1.387039845,
      1.306562965,
      1.175875602,
      1.0,
      0.785694958,
      0.541196100,
      0.275899379,
    ];
    var k = 0;
    for (var row = 0; row < 8; row++) {
      for (var col = 0; col < 8; col++) {
        final s = aasf[row] * aasf[col] * 8.0;
        _fdtblY[k] = 1.0 / (_yTable[_zigZag[k]] * s);
        _fdtblUv[k] = 1.0 / (_uvTable[_zigZag[k]] * s);
        k++;
      }
    }
  }

  static List<(int, int)?> _huffman(List<int> codes, List<int> values) {
    final table = List<(int, int)?>.filled(256, null);
    var code = 0, pos = 0;
    for (var len = 1; len <= 16; len++) {
      for (var j = 0; j < codes[len]; j++) {
        table[values[pos++]] = (code++, len);
      }
      code *= 2;
    }
    return table;
  }

  void _writeHeaders(int width, int height) {
    void bytes(List<int> b) => _out.add(b);
    void word(int v) => bytes([(v >> 8) & 0xFF, v & 0xFF]);
    bytes([0xFF, 0xD8]); // SOI
    // APP0 JFIF
    bytes([0xFF, 0xE0]);
    word(16);
    bytes([0x4A, 0x46, 0x49, 0x46, 0, 1, 1, 0]);
    word(1);
    word(1);
    bytes([0, 0]);
    // DQT
    bytes([0xFF, 0xDB]);
    word(132);
    bytes([0]);
    bytes(_yTable);
    bytes([1]);
    bytes(_uvTable);
    // SOF0
    bytes([0xFF, 0xC0]);
    word(17);
    bytes([8]);
    word(height);
    word(width);
    bytes([3, 1, 0x11, 0, 2, 0x11, 1, 3, 0x11, 1]);
    // DHT (one DC and one AC table shared by all components)
    bytes([0xFF, 0xC4]);
    word(2 + 1 + 16 + _dcLumValues.length + 1 + 16 + _acLumValues.length);
    bytes([0x00]);
    bytes(_dcLumCodes.sublist(1));
    bytes(_dcLumValues);
    bytes([0x10]);
    bytes(_acLumCodes.sublist(1));
    bytes(_acLumValues);
    // SOS
    bytes([0xFF, 0xDA]);
    word(12);
    bytes([3, 1, 0, 2, 0, 3, 0, 0, 0x3F, 0]);
  }

  void _writeBits(int value, int length) {
    for (var p = length - 1; p >= 0; p--) {
      if (value & (1 << p) != 0) _byteNew |= 1 << _bytePos;
      _bytePos--;
      if (_bytePos < 0) {
        _out.addByte(_byteNew);
        if (_byteNew == 0xFF) _out.addByte(0);
        _bytePos = 7;
        _byteNew = 0;
      }
    }
  }

  void _writeCode((int, int)? code) {
    final (value, length) = code!;
    _writeBits(value, length);
  }

  static int _category(int v) {
    var a = v.abs(), n = 0;
    while (a > 0) {
      n++;
      a >>= 1;
    }
    return n;
  }

  void _writeValue(int v, int category) {
    final bits = v > 0 ? v : v + (1 << category) - 1;
    _writeBits(bits, category);
  }

  int _processDu(Float64List block, Float64List fdtbl, int dc) {
    final d = _work..setAll(0, block);
    _fdct(d);
    for (var i = 0; i < 64; i++) {
      final q = d[i] * fdtbl[i];
      _du[_zigZag[i]] = q > 0 ? (q + 0.5).toInt() : (q - 0.5).toInt();
    }
    final diff = _du[0] - dc;
    if (diff == 0) {
      _writeCode(_dcTable[0]);
    } else {
      final cat = _category(diff);
      _writeCode(_dcTable[cat]);
      _writeValue(diff, cat);
    }
    var end = 63;
    while (end > 0 && _du[end] == 0) {
      end--;
    }
    if (end == 0) {
      _writeCode(_acTable[0x00]);
      return _du[0];
    }
    var i = 1;
    while (i <= end) {
      final start = i;
      while (_du[i] == 0 && i <= end) {
        i++;
      }
      var zeros = i - start;
      if (zeros >= 16) {
        for (var m = 0; m < zeros >> 4; m++) {
          _writeCode(_acTable[0xF0]);
        }
        zeros &= 15;
      }
      final cat = _category(_du[i]);
      _writeCode(_acTable[(zeros << 4) + cat]);
      _writeValue(_du[i], cat);
      i++;
    }
    if (end != 63) _writeCode(_acTable[0x00]);
    return _du[0];
  }

  /// AAN forward DCT, in place, rows then columns.
  static void _fdct(Float64List d) {
    for (var pass = 0; pass < 2; pass++) {
      final stride = pass == 0 ? 1 : 8;
      for (var n = 0; n < 8; n++) {
        final o = pass == 0 ? n * 8 : n;
        final d0 = d[o], d1 = d[o + stride], d2 = d[o + 2 * stride];
        final d3 = d[o + 3 * stride], d4 = d[o + 4 * stride];
        final d5 = d[o + 5 * stride], d6 = d[o + 6 * stride];
        final d7 = d[o + 7 * stride];
        final tmp0 = d0 + d7, tmp7 = d0 - d7, tmp1 = d1 + d6, tmp6 = d1 - d6;
        final tmp2 = d2 + d5, tmp5 = d2 - d5, tmp3 = d3 + d4, tmp4 = d3 - d4;
        var tmp10 = tmp0 + tmp3;
        final tmp13 = tmp0 - tmp3;
        var tmp11 = tmp1 + tmp2;
        var tmp12 = tmp1 - tmp2;
        d[o] = tmp10 + tmp11;
        d[o + 4 * stride] = tmp10 - tmp11;
        final z1 = (tmp12 + tmp13) * 0.707106781;
        d[o + 2 * stride] = tmp13 + z1;
        d[o + 6 * stride] = tmp13 - z1;
        tmp10 = tmp4 + tmp5;
        tmp11 = tmp5 + tmp6;
        tmp12 = tmp6 + tmp7;
        final z5 = (tmp10 - tmp12) * 0.382683433;
        final z2 = 0.541196100 * tmp10 + z5;
        final z4 = 1.306562965 * tmp12 + z5;
        final z3 = tmp11 * 0.707106781;
        final z11 = tmp7 + z3, z13 = tmp7 - z3;
        d[o + 5 * stride] = z13 + z2;
        d[o + 3 * stride] = z13 - z2;
        d[o + stride] = z11 + z4;
        d[o + 7 * stride] = z11 - z4;
      }
    }
  }

  static const _zigZag = [
    0, 1, 5, 6, 14, 15, 27, 28, 2, 4, 7, 13, 16, 26, 29, 42, //
    3, 8, 12, 17, 25, 30, 41, 43, 9, 11, 18, 24, 31, 40, 44, 53,
    10, 19, 23, 32, 39, 45, 52, 54, 20, 22, 33, 38, 46, 51, 55, 60,
    21, 34, 37, 47, 50, 56, 59, 61, 35, 36, 48, 49, 57, 58, 62, 63,
  ];

  static const _yqt = [
    16, 11, 10, 16, 24, 40, 51, 61, 12, 12, 14, 19, 26, 58, 60, 55, //
    14, 13, 16, 24, 40, 57, 69, 56, 14, 17, 22, 29, 51, 87, 80, 62,
    18, 22, 37, 56, 68, 109, 103, 77, 24, 35, 55, 64, 81, 104, 113, 92,
    49, 64, 78, 87, 103, 121, 120, 101, 72, 92, 95, 98, 112, 100, 103, 99,
  ];

  static const _uvqt = [
    17, 18, 24, 47, 99, 99, 99, 99, 18, 21, 26, 66, 99, 99, 99, 99, //
    24, 26, 56, 99, 99, 99, 99, 99, 47, 66, 99, 99, 99, 99, 99, 99,
    99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,
    99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,
  ];

  static const _dcLumCodes = [
    0,
    0,
    1,
    5,
    1,
    1,
    1,
    1,
    1,
    1,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
  ];
  static const _dcLumValues = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
  static const _acLumCodes = [
    0, 0, 2, 1, 3, 3, 2, 4, 3, 5, 5, 4, 4, 0, 0, 1, 0x7d, //
  ];
  static const _acLumValues = [
    0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, 0x21, 0x31, 0x41, 0x06, //
    0x13, 0x51, 0x61, 0x07, 0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xa1, 0x08,
    0x23, 0x42, 0xb1, 0xc1, 0x15, 0x52, 0xd1, 0xf0, 0x24, 0x33, 0x62, 0x72,
    0x82, 0x09, 0x0a, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x25, 0x26, 0x27, 0x28,
    0x29, 0x2a, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x43, 0x44, 0x45,
    0x46, 0x47, 0x48, 0x49, 0x4a, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59,
    0x5a, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6a, 0x73, 0x74, 0x75,
    0x76, 0x77, 0x78, 0x79, 0x7a, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
    0x8a, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0xa2, 0xa3,
    0xa4, 0xa5, 0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6,
    0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3, 0xc4, 0xc5, 0xc6, 0xc7, 0xc8, 0xc9,
    0xca, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda, 0xe1, 0xe2,
    0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea, 0xf1, 0xf2, 0xf3, 0xf4,
    0xf5, 0xf6, 0xf7, 0xf8, 0xf9, 0xfa,
  ];
}
