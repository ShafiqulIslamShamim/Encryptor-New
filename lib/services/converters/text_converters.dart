import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Port of the conversion helpers in Java `ConvertTextStrings` and
/// `StringBinaryConverter`.
class TextConverters {
  TextConverters._();

  /// Percent (URL) encoding — port of Java `ConvertTextStrings.a(String)`.
  ///
  /// Encodes UTF-8 bytes, keeping RFC 3986 unreserved characters
  /// (`A-Z a-z 0-9 - . _ ~`) as-is, percent-encoding everything else with
  /// **uppercase** hex digits — matching Java's `"0123456789ABCDEF"` table.
  static String urlEncode(String input) {
    final bytes = utf8.encode(input);
    final out = StringBuffer();
    const hexTable = '0123456789ABCDEF';
    for (final b in bytes) {
      // Java condition: keep if unreserved (letters, digits, '-', '.', '_', '~')
      final v = b & 0xFF;
      if ((v >= 0x61 && v <= 0x7A) || // a-z
          (v >= 0x41 && v <= 0x5A) || // A-Z
          (v >= 0x30 && v <= 0x39) || // 0-9
          v == 0x2D || // -
          v == 0x2E || // .
          v == 0x5F || // _
          v == 0x7E) { // ~
        out.writeCharCode(v);
      } else {
        out
          ..write('%')
          ..write(hexTable[(b >> 4) & 0xF])
          ..write(hexTable[b & 0xF]);
      }
    }
    return out.toString();
  }

  /// Percent decoding — port of Java `ConvertTextStrings.b(String)`.
  ///
  /// Replicates the exact Java behavior: literal (non-`%`) characters are
  /// written inline, while all `%HH` bytes are **collected** and appended
  /// together at the end decoded as a single UTF-8 sequence.
  ///
  /// For fully-encoded input (output of [urlEncode]) this produces the
  /// correct result. Throws [FormatException] on invalid `%HH` sequences,
  /// and returns `null` on empty input (callers should guard).
  static String urlDecode(String input) {
    if (input.isEmpty) return '';
    final sb = StringBuffer();
    final bytes = Uint8List(input.length); // upper-bound size
    int byteIndex = 0;

    for (int i = 0; i < input.length; i++) {
      final c = input[i];
      if (c != '%') {
        sb.write(c);
      } else {
        if (i + 2 >= input.length) {
          throw const FormatException('Truncated percent-escape');
        }
        final hex = input.substring(i + 1, i + 3);
        final byte = int.tryParse(hex, radix: 16);
        if (byte == null) throw FormatException('Invalid hex escape %$hex');
        bytes[byteIndex++] = byte;
        i += 2;
      }
    }
    if (byteIndex > 0) {
      sb.write(utf8.decode(bytes.sublist(0, byteIndex), allowMalformed: true));
    }
    return sb.toString();
  }

  /// Java `ConvertTextStrings.n(String)` — text to `\uXXXX` escapes.
  ///
  /// Iterates UTF-16 code units, so supplementary characters become two
  /// escapes. ASCII (0..127) is kept as-is; escapes use UPPERCASE hex.
  static String unicodeEncode(String input) {
    if (input.isEmpty) return input;
    final out = StringBuffer();
    for (final unit in input.codeUnits) {
      if (unit >= 128) {
        out
          ..write('\\u')
          ..write(unit.toRadixString(16).toUpperCase().padLeft(4, '0'));
      } else {
        out.writeCharCode(unit);
      }
    }
    return out.toString();
  }

  /// Java `ConvertTextStrings.m(String)` — `\uXXXX` escapes to text.
  static String unicodeDecode(String input) {
    return input.replaceAllMapped(
      RegExp(r'\\u([0-9a-fA-F]{4})'),
      (match) => String.fromCharCode(
        int.parse(match.group(1)!, radix: 16),
      ),
    );
  }

  /// Java `StringBinaryConverter.textToBinary`.
  ///
  /// UTF-8 bytes, each written as exactly 8 bits, with no separators.
  static String textToBinary(String text) {
    return utf8.encode(text).map((b) => b.toRadixString(2).padLeft(8, '0')).join();
  }

  /// Java `StringBinaryConverter.binaryToText`.
  ///
  /// Groups into 8-bit chunks; trailing bits that do not form a full byte are
  /// ignored (integer division), like the original.
  static String binaryToText(String binary) {
    final byteCount = binary.length ~/ 8;
    final bytes = <int>[];
    for (int i = 0; i < byteCount; i++) {
      bytes.add(int.parse(binary.substring(i * 8, (i + 1) * 8), radix: 2));
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Java `ConvertTextStrings.a(String, String)` — MessageDigest hex digest.
  ///
  /// Empty input yields an empty string; supported algorithms match the
  /// converter values used by `ConversionManager`: MD5, SHA-1, SHA-224,
  /// SHA-256, SHA-384, SHA-512.
  static String hash(String input, String algorithm) {
    if (input.isEmpty) return '';

    final Digest digest = switch (algorithm.toUpperCase()) {
      'MD5' => MD5Digest(),
      'SHA-1' || 'SHA1' => SHA1Digest(),
      'SHA-224' || 'SHA224' => SHA224Digest(),
      'SHA-256' || 'SHA256' => SHA256Digest(),
      'SHA-384' || 'SHA384' => SHA384Digest(),
      'SHA-512' || 'SHA512' => SHA512Digest(),
      _ => throw ArgumentError('Unsupported digest: $algorithm'),
    };

    digest.reset();
    final result = digest.process(Uint8List.fromList(utf8.encode(input)));
    return bytesToCompactHex(result);
  }

  /// Java `ConvertTextStrings.a(byte[])` — lowercase 2-digit hex, no separator.
  static String bytesToCompactHex(List<int> bytes) {
    return bytes.map((b) => (b & 0xFF).toRadixString(16).padLeft(2, '0')).join();
  }

  /// Java `ConvertTextStrings.a(byte[], String)` — `0x` + unpadded lowercase
  /// hex per byte, followed by [separator] after EVERY byte (including last).
  static String bytesTo0xHex(List<int> bytes, String separator) {
    final out = StringBuffer();
    for (final byte in bytes) {
      out
        ..write('0x')
        ..write((byte & 0xFF).toRadixString(16))
        ..write(separator);
    }
    return out.toString();
  }

  /// Java `ConvertTextStrings.l(String)` — sanitized pairs of hex digits to
  /// bytes. Odd-length input leaves the final single nibble as a byte.
  static List<int> hexToBytes(String sanitizedHex) {
    final bytes = <int>[];
    for (int i = 0; i < sanitizedHex.length; i += 2) {
      final end = (i + 2 <= sanitizedHex.length) ? i + 2 : sanitizedHex.length;
      bytes.add(int.parse(sanitizedHex.substring(i, end), radix: 16) & 0xFF);
    }
    return bytes;
  }

  /// Java `ConvertTextStrings.a(String[])` — `0xNN` lines to bytes; the first
  /// two characters of each line are dropped unconditionally.
  static List<int> linesToBytes(List<String> lines) {
    return lines.map((line) {
      final trimmed = line.trim();
      final stripped = trimmed.length >= 2 ? trimmed.substring(2) : '';
      final hex = stripped.replaceAll(RegExp(r'[^A-Fa-f0-9]'), '');
      return hex.isEmpty ? 0 : int.parse(hex, radix: 16) & 0xFF;
    }).toList();
  }

  /// Splits a compact hex string into space-separated pairs, like Java's
  /// `replaceAll("..(?!$)", "$0 ")`.
  static String groupHexPairs(String hex) {
    final out = StringBuffer();
    for (int i = 0; i < hex.length; i += 2) {
      if (i > 0) out.write(' ');
      out.write(hex.substring(i, (i + 2 <= hex.length) ? i + 2 : hex.length));
    }
    return out.toString();
  }
}
