/// Port of Java `NumberSystemUtils`, `BinaryCalculator` and the number-system
/// branches of `ConversionManager` (values 16-20, 32).
class NumberConverters {
  NumberConverters._();

  static const int _int32Min = -0x80000000;
  static const int _int32Max = 0x7FFFFFFF;
  static const int _int64Min = -0x8000000000000000;
  static const int _int64Max = 0x7FFFFFFFFFFFFFFF;

  // ---------------- Reverse helpers (Java NumberSystemUtils.fromX) ----------------

  static String fromDecimal(String input) {
    final value = _parseInt64(input, radix: 10);
    return value == null ? 'Invalid Decimal' : value.toString();
  }

  static String fromBinary(String input) {
    if (input.startsWith('-')) {
      final magnitude = _parseInt64(input.substring(1), radix: 2);
      return magnitude == null ? 'Invalid Binary' : '-$magnitude';
    }
    final value = _parseInt64(input, radix: 2);
    return value == null ? 'Invalid Binary' : value.toString();
  }

  static String fromOctal(String input) {
    if (input.startsWith('-')) {
      final magnitude = _parseInt64(input.substring(1), radix: 8);
      return magnitude == null ? 'Invalid Octal' : '-$magnitude';
    }
    final value = _parseInt64(input, radix: 8);
    return value == null ? 'Invalid Octal' : value.toString();
  }

  static String fromHex(String input) {
    var text = input.trim();
    final isNegative = text.startsWith('-');
    if (isNegative) text = text.substring(1);
    if (text.startsWith('0x') || text.startsWith('0X')) {
      text = text.substring(2);
    }
    final value = _parseInt64(text, radix: 16);
    return value == null ? 'Invalid Hex' : '${isNegative ? '-' : ''}$value';
  }

  // ---------------- Forward conversions (Java ConversionManager 16-20) ----------------

  /// Formats the four-line result exactly like `setCopyableResults`.
  static String formatResults({
    required String decimal,
    required String binary,
    required String octal,
    required String hex,
  }) {
    return 'Decimal: $decimal\n'
        'Binary:  $binary\n'
        'Octal:   $octal\n'
        'Hex:     $hex';
  }

  /// Case 16: decimal (32-bit int) to binary / octal / hex.
  static String decimalToBases(String input) {
    final value = _parseInt32OrThrow(input, radix: 10);
    return formatResults(
      decimal: value.toString(),
      binary: _binary32(value),
      octal: _octal32(value),
      hex: _hex32(value),
    );
  }

  /// Case 17: binary (32-bit int) to decimal / octal / hex.
  static String binaryToBases(String input) {
    final value = _parseInt32OrThrow(input, radix: 2);
    return formatResults(
      decimal: value.toString(),
      binary: input,
      octal: _octal32(value),
      hex: _hex32(value),
    );
  }

  /// Case 18: octal (32-bit int) to decimal / binary / hex.
  static String octalToBases(String input) {
    final value = _parseInt32OrThrow(input, radix: 8);
    return formatResults(
      decimal: value.toString(),
      binary: _binary32(value),
      octal: input,
      hex: _hex32(value),
    );
  }

  /// Case 19: hex without prefix (32-bit int) to decimal / binary / octal.
  static String hexToBases(String input) {
    final value = _parseInt32OrThrow(input, radix: 16);
    return formatResults(
      decimal: value.toString(),
      binary: _binary32(value),
      octal: _octal32(value),
      hex: _hex32(value),
    );
  }

  /// Case 20: `0x`-prefixed hex. Keeps the original quirk: the number after
  /// the prefix is parsed as DECIMAL (long), then rendered as padded hex.
  static String hex0xToBases(String input) {
    // The Java filter keeps [0-9a-fA-FxX] and drops '-'. It then calls
    // Long.parseLong(value), i.e. base 10, on the remaining text.
    var valueText = input.replaceAll('-', '');
    if (valueText.startsWith('0x') || valueText.startsWith('0X')) {
      valueText = valueText.substring(2);
    }
    final value = _parseInt64(valueText, radix: 10) ??
        (throw const FormatException('Invalid decimal'));

    var hex = _hex64(value);
    while (hex.length < 8) {
      hex = '0$hex';
    }
    return formatResults(
      decimal: value.toString(),
      binary: _binary64(value),
      octal: _octal64(value),
      hex: '0x$hex',
    );
  }

  // ---------------- BinaryCalculator.calculate (case 32) ----------------

  /// BigInteger-based binary addition / subtraction with sign-magnitude
  /// output. All non `0`/`1` characters are stripped; every `+`/`-` is a
  /// segment boundary. Empty/whitespace input returns an empty string.
  static String calculateBinary(String input) {
    if (input.trim().isEmpty) return '';

    var text = input.replaceAll(RegExp(r'\s+'), '');
    if (!text.startsWith('+') && !text.startsWith('-')) {
      text = '+$text';
    }

    var result = BigInt.zero;
    int index = 0;
    while (index < text.length) {
      final sign = text.codeUnitAt(index++);
      final start = index;
      while (index < text.length &&
          text.codeUnitAt(index) != 0x2B &&
          text.codeUnitAt(index) != 0x2D) {
        index++;
      }

      var binary = text.substring(start, index).replaceAll(RegExp(r'[^01]'), '');
      if (binary.isEmpty) binary = '0';
      if (binary == '0') continue;

      var value = BigInt.parse(binary, radix: 2);
      if (sign == 0x2D) value = -value;
      result += value;
    }

    if (result == BigInt.zero) return '0';
    final sign = result.isNegative ? '-' : '';
    return '$sign${result.abs().toRadixString(2)}';
  }

  // ---------------- Java-style integer formatting ----------------

  static String _binary32(int value) => (value & 0xFFFFFFFF).toRadixString(2);
  static String _octal32(int value) => (value & 0xFFFFFFFF).toRadixString(8);
  static String _hex32(int value) =>
      (value & 0xFFFFFFFF).toRadixString(16).toUpperCase();

  static String _binary64(int value) =>
      (value & 0xFFFFFFFFFFFFFFFF).toRadixString(2);
  static String _octal64(int value) =>
      (value & 0xFFFFFFFFFFFFFFFF).toRadixString(8);
  static String _hex64(int value) =>
      (value & 0xFFFFFFFFFFFFFFFF).toRadixString(16).toUpperCase();

  static int? _parseInt64(String text, {int radix = 10}) {
    final value = int.tryParse(text, radix: radix);
    if (value == null || value < _int64Min || value > _int64Max) return null;
    return value;
  }

  static int _parseInt32OrThrow(String text, {int radix = 10}) {
    final value = _parseInt64(text, radix: radix);
    if (value == null || value < _int32Min || value > _int32Max) {
      throw FormatException('Invalid integer', text);
    }
    return value;
  }
}
