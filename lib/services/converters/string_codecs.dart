import 'dart:convert';

/// Charset helpers used by the byte-array conversions (Java cases 9-15).
///
/// Java `String.getBytes(charset)` and `new String(bytes, charset)` operate on
/// UTF-16 code units, which is why Dart's [String.codeUnits] is used here for
/// UTF-16 / Latin-1 / ASCII / CP1251.
class StringCodecs {
  StringCodecs._();

  // Windows-1251 mapping for bytes 0x80..0xFF (Unicode version 2.0 table).
  // 0x98 is undefined in the table and is decoded as '?' here.
  static const List<int> _cp1251High = [
    0x0402, 0x0403, 0x201A, 0x0453, 0x201E, 0x2026, 0x2020, 0x2021,
    0x20AC, 0x2030, 0x0409, 0x2039, 0x040A, 0x040C, 0x040B, 0x040F,
    0x0452, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
    0x003F, 0x2122, 0x0459, 0x203A, 0x045A, 0x045C, 0x045B, 0x045F,
    0x00A0, 0x040E, 0x045E, 0x0408, 0x00A4, 0x0490, 0x00A6, 0x00A7,
    0x0401, 0x00A9, 0x0404, 0x00AB, 0x00AC, 0x00AD, 0x00AE, 0x0407,
    0x00B0, 0x00B1, 0x0406, 0x0456, 0x0491, 0x00B5, 0x00B6, 0x00B7,
    0x0451, 0x2116, 0x0454, 0x00BB, 0x0458, 0x0405, 0x0455, 0x0457,
    0x0410, 0x0411, 0x0412, 0x0413, 0x0414, 0x0415, 0x0416, 0x0417,
    0x0418, 0x0419, 0x041A, 0x041B, 0x041C, 0x041D, 0x041E, 0x041F,
    0x0420, 0x0421, 0x0422, 0x0423, 0x0424, 0x0425, 0x0426, 0x0427,
    0x0428, 0x0429, 0x042A, 0x042B, 0x042C, 0x042D, 0x042E, 0x042F,
    0x0430, 0x0431, 0x0432, 0x0433, 0x0434, 0x0435, 0x0436, 0x0437,
    0x0438, 0x0439, 0x043A, 0x043B, 0x043C, 0x043D, 0x043E, 0x043F,
    0x0440, 0x0441, 0x0442, 0x0443, 0x0444, 0x0445, 0x0446, 0x0447,
    0x0448, 0x0449, 0x044A, 0x044B, 0x044C, 0x044D, 0x044E, 0x044F,
  ];

  static final Map<int, int> _cp1251Reverse = _buildCp1251Reverse();

  static Map<int, int> _buildCp1251Reverse() {
    final map = <int, int>{};
    for (int i = 0; i < 0x80; i++) {
      map[i] = i;
    }
    for (int i = 0; i < _cp1251High.length; i++) {
      map[_cp1251High[i]] = 0x80 + i;
    }
    return map;
  }

  /// Dispatches by the charset name used in Java (`UTF-8`, `UTF-16`,
  /// `UTF-16LE`, `UTF-16BE`, `US-ASCII`, `ISO-8859-1`, `CP1251`).
  static List<int> encode(String text, String charset) {
    switch (charset) {
      case 'UTF-8':
        return utf8.encode(text);
      case 'UTF-16':
        return [0xFE, 0xFF, ..._encodeUtf16(text, littleEndian: false)];
      case 'UTF-16LE':
        return _encodeUtf16(text, littleEndian: true);
      case 'UTF-16BE':
        return _encodeUtf16(text, littleEndian: false);
      case 'US-ASCII':
        return ascii.encode(text);
      case 'ISO-8859-1':
        return latin1.encode(text);
      case 'CP1251':
        return text.codeUnits
            .map((c) => _cp1251Reverse[c] ?? 0x3F)
            .toList();
      default:
        return utf8.encode(text);
    }
  }

  static String decode(List<int> bytes, String charset) {
    switch (charset) {
      case 'UTF-8':
        return utf8.decode(bytes, allowMalformed: true);
      case 'UTF-16':
        return _decodeUtf16(bytes);
      case 'UTF-16LE':
        return _decodeUtf16(bytes, forceLittleEndian: true);
      case 'UTF-16BE':
        return _decodeUtf16(bytes, forceLittleEndian: false);
      case 'US-ASCII':
        return ascii.decode(bytes);
      case 'ISO-8859-1':
        return latin1.decode(bytes);
      case 'CP1251':
        return String.fromCharCodes(
          bytes.map((b) => b < 0x80 ? b : _cp1251High[b - 0x80]),
        );
      default:
        return utf8.decode(bytes, allowMalformed: true);
    }
  }

  static List<int> _encodeUtf16(String text, {required bool littleEndian}) {
    final bytes = <int>[];
    for (final unit in text.codeUnits) {
      final high = (unit >> 8) & 0xFF;
      final low = unit & 0xFF;
      if (littleEndian) {
        bytes
          ..add(low)
          ..add(high);
      } else {
        bytes
          ..add(high)
          ..add(low);
      }
    }
    return bytes;
  }

  static String _decodeUtf16(List<int> bytes, {bool? forceLittleEndian}) {
    var offset = 0;
    var littleEndian = forceLittleEndian ?? false;

    if (forceLittleEndian == null && bytes.length >= 2) {
      if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
        littleEndian = false;
        offset = 2;
      } else if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
        littleEndian = true;
        offset = 2;
      }
    }

    final units = <int>[];
    for (int i = offset; i + 1 < bytes.length; i += 2) {
      final first = bytes[i];
      final second = bytes[i + 1];
      units.add(littleEndian ? (second << 8) | first : (first << 8) | second);
    }
    return String.fromCharCodes(units);
  }
}
