/// Port of Java `ColorConverterTextStrings` and the color helpers used by
/// `ConversionManager` (cases 26, 28, 29).
///
/// Colors are represented as packed 32-bit ARGB integers, exactly like
/// Android's `int` color representation.
class ColorConverters {
  ColorConverters._();

  static const int opaqueBlack = 0xFF000000;

  /// Java `ColorConverterTextStrings.a` / `c`.
  ///
  /// Hex number (optional leading `-` and `0x`) to `#AARRGGBB`, always 8
  /// lowercase digits. Returns null on invalid input.
  static String? hexNumberToArgbHex(String input) {
    if (input.isEmpty) return null;
    var text = input;
    var sign = '';
    if (text.startsWith('-')) {
      text = text.substring(1);
      sign = '-';
    }
    if (text.startsWith('0x')) text = text.substring(2);
    if (!RegExp(r'^[0-9A-Fa-f]+$').hasMatch(text)) return null;

    final value = int.tryParse('$sign$text', radix: 16);
    if (value == null) return null;
    return '#${(value & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0')}';
  }

  /// Java `ColorConverterTextStrings.b`.
  ///
  /// `#RRGGBB` to `0xAARRGGBB`. Keeps the original regex precedence quirk:
  /// only 6-digit `#RRGGBB` is accepted.
  static String? rgbHexTo0xArgb(String input) {
    if (input.isEmpty) return null;
    var text = normalizeHex(input);
    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(text)) return null;
    final color = parseColor(text);
    if (color == null) return null;
    return '0x${(color & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0')}';
  }

  /// Java `ColorConverterTextStrings.d`.
  ///
  /// `#RRGGBB` / `#AARRGGBB` to smali-style hex: `-0x...` when alpha >= 128,
  /// otherwise `0x...`. Java `Integer.toHexString` emits variable-length
  /// lowercase hex for positive values and 8 digits for negative values.
  static String colorToSmaliHex(String input) {
    var text = normalizeHex(input);
    final color = parseColor(text);
    if (color == null) throw const FormatException('Invalid color');

    final alpha = (color >> 24) & 0xFF;
    if (alpha >= 128) {
      final negated = _javaNegate(color);
      return '-0x${javaIntToHexString(negated)}';
    }
    return '0x${javaIntToHexString(color)}';
  }

  /// Java `Integer.toHexString(int)` semantics on a 32-bit signed integer.
  static String javaIntToHexString(int value) {
    final signed = toSigned32(value);
    if (signed < 0) {
      return (signed & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
    }
    return signed.toRadixString(16);
  }

  /// Java `String.format("#%08x", int)`.
  static String toPackedHex(int value) => formatArgbHex(value);

  /// Adds the leading `#` used by Android `Color.parseColor` call sites.
  static String normalizeHex(String text) =>
      text.startsWith('#') ? text : '#$text';

  /// Formats a packed ARGB integer as `#AARRGGBB` with 8 digits.
  static String formatArgbHex(int color, {bool uppercase = false}) {
    final hex = (color & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
    return '#${uppercase ? hex.toUpperCase() : hex}';
  }

  /// Java `Color.argb(a, r, g, b)`.
  static int argb(int a, int r, int g, int b) {
    return ((a & 0xFF) << 24) |
        ((r & 0xFF) << 16) |
        ((g & 0xFF) << 8) |
        (b & 0xFF);
  }

  static int alpha(int color) => (color >> 24) & 0xFF;
  static int red(int color) => (color >> 16) & 0xFF;
  static int green(int color) => (color >> 8) & 0xFF;
  static int blue(int color) => color & 0xFF;

  /// Java `ConvertTextStrings.j(String)` — validates 3 or 4 comma-separated
  /// components where each component is an integer in 0..255.
  static bool isValidRgba(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return false;
    final parts = trimmed.split(',');
    if (parts.length != 3 && parts.length != 4) return false;
    for (final part in parts) {
      final v = int.tryParse(part.trim());
      if (v == null || v < 0 || v > 255) return false;
    }
    return true;
  }

  /// Java `ConvertTextStrings.k(String)` — `"r,g,b"` or `"a,r,g,b"` to ARGB.
  static int rgbStringToArgb(String input) {
    try {
      final parts = input.trim().split(',').map((p) => p.trim()).toList();
      if (parts.length == 3) {
        return argb(255, int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }
      return argb(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
        int.parse(parts[3]),
      );
    } catch (_) {
      return opaqueBlack;
    }
  }

  /// Minimal equivalent of Android `Color.parseColor` for the formats used
  /// here: `#RGB`, `#ARGB`, `#RRGGBB`, `#AARRGGBB`.
  static int? parseColor(String input) {
    var text = input.trim();
    if (!text.startsWith('#')) return null;
    text = text.substring(1);

    if (text.length == 3) {
      final r = int.tryParse(text[0] * 2, radix: 16);
      final g = int.tryParse(text[1] * 2, radix: 16);
      final b = int.tryParse(text[2] * 2, radix: 16);
      if (r == null || g == null || b == null) return null;
      return argb(255, r, g, b);
    }
    if (text.length == 4) {
      final a = int.tryParse(text[0] * 2, radix: 16);
      final r = int.tryParse(text[1] * 2, radix: 16);
      final g = int.tryParse(text[2] * 2, radix: 16);
      final b = int.tryParse(text[3] * 2, radix: 16);
      if (a == null || r == null || g == null || b == null) return null;
      return argb(a, r, g, b);
    }
    if (text.length == 6 || text.length == 8) {
      final value = int.tryParse(text, radix: 16);
      if (value == null) return null;
      if (text.length == 6) return (0xFF000000 | value);
      return value;
    }
    return null;
  }

  /// Casts an integer to a signed 32-bit int, matching Java `int` semantics.
  static int toSigned32(int value) {
    final v = value & 0xFFFFFFFF;
    return v >= 0x80000000 ? v - 0x100000000 : v;
  }

  /// Java int negation with 32-bit overflow.
  static int _javaNegate(int value) {
    return toSigned32(-toSigned32(value));
  }
}
