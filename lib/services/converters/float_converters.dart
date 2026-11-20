import 'dart:typed_data';

/// IEEE-754 32-bit float conversions (Java `ConversionManager` cases 21-25).
///
/// Java casts the float's int bit pattern to `long` before calling
/// `Long.toBinaryString` / `Long.toOctalString`, so negative bit patterns are
/// rendered as 64-character two's-complement strings. This is reproduced
/// here by formatting through the 64-bit mask.
class FloatConverters {
  FloatConverters._();

  static int floatToIntBits(double value) {
    final buffer = ByteData(4);
    buffer.setFloat32(0, value, Endian.host);
    return _toSigned32(buffer.getUint32(0, Endian.host));
  }

  static double intBitsToFloat(int bits) {
    final buffer = ByteData(4)
      ..setUint32(0, bits & 0xFFFFFFFF, Endian.host);
    return buffer.getFloat32(0, Endian.host);
  }

  /// Case 21: decimal float -> 64-bit-style binary bit string.
  static String encodeBinary(String input) {
    final split = _stripSign(input);
    final bits = floatToIntBits(double.parse(split.value));
    return '${split.sign}${_binary64(bits)}';
  }

  /// Case 21 reverse.
  static String decodeBinary(String result) {
    final split = _stripSign(result);
    final bits = int.parse(split.value, radix: 2);
    return '${split.sign}${intBitsToFloat(bits)}';
  }

  /// Case 22: decimal float -> octal bit string.
  static String encodeOctal(String input) {
    final split = _stripSign(input);
    final bits = floatToIntBits(double.parse(split.value));
    return '${split.sign}${_octal64(bits)}';
  }

  /// Case 22 reverse.
  static String decodeOctal(String result) {
    final split = _stripSign(result);
    final bits = int.parse(split.value, radix: 8);
    return '${split.sign}${intBitsToFloat(bits)}';
  }

  /// Case 23: `%x`, no prefix.
  static String encodeHex(String input) {
    return _javaIntHex(floatToIntBits(double.parse(input)));
  }

  /// Case 24: `0x` + `%x`.
  static String encodeHex0x(String input) {
    return '0x${encodeHex(input)}';
  }

  /// Case 25: `0x` + `%08x`.
  static String encodeHex0xPadded(String input) {
    final hex = encodeHex(input);
    return '0x${hex.padLeft(8, '0')}';
  }

  /// Cases 23-25 reverse: strip optional `-`, then optional `0x`, parse hex.
  static String decodeHex(String result) {
    var text = result.trim();
    var sign = '';
    if (text.startsWith('-')) {
      text = text.substring(1);
      sign = '-';
    }
    if (text.startsWith('0x')) text = text.substring(2);
    final bits = int.parse(text, radix: 16);
    return '$sign${intBitsToFloat(bits)}';
  }

  static _SignSplit _stripSign(String text) {
    if (text.startsWith('-')) {
      return _SignSplit('-', text.substring(1));
    }
    return _SignSplit('', text);
  }

  static String _binary64(int value) =>
      (value & 0xFFFFFFFFFFFFFFFF).toRadixString(2);

  static String _octal64(int value) =>
      (value & 0xFFFFFFFFFFFFFFFF).toRadixString(8);

  static String _javaIntHex(int value) {
    if (value < 0) {
      return (value & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
    }
    return value.toRadixString(16);
  }

  static int _toSigned32(int value) {
    final v = value & 0xFFFFFFFF;
    return v >= 0x80000000 ? v - 0x100000000 : v;
  }
}

class _SignSplit {
  final String sign;
  final String value;

  const _SignSplit(this.sign, this.value);
}
