import 'dart:convert';

import 'converters/color_converters.dart';
import 'converters/crypto_converters.dart';
import 'converters/float_converters.dart';
import 'converters/number_converters.dart';
import 'converters/string_codecs.dart';
import 'converters/text_converters.dart';
import 'password_manager.dart';

/// The outcome of one conversion pass.
///
/// A non-null [input] / [result] means "write this value into that field".
/// [error] carries a message for the inline error banner. Ports the Java
/// `ConversionManager.performConversion` behaviour, including which fields
/// are force-filtered and which results are read-only.
class ConversionResult {
  final String? input;
  final String? result;
  final String? error;
  final bool readOnlyResult;

  const ConversionResult({
    this.input,
    this.result,
    this.error,
    this.readOnlyResult = false,
  });
}

/// Port of Java `ConversionManager`, with every switch case from 0 to 32.
class ConversionManager {
  ConversionManager._();

  static const Map<int, String> _charsets = {
    9: 'UTF-8',
    10: 'UTF-16',
    11: 'UTF-16LE',
    12: 'UTF-16BE',
    13: 'US-ASCII',
    14: 'ISO-8859-1',
    15: 'CP1251',
  };

  static const Map<int, String> _hashAlgorithms = {
    3: 'MD5',
    4: 'SHA-1',
    5: 'SHA-224',
    6: 'SHA-256',
    7: 'SHA-384',
    8: 'SHA-512',
  };

  static Future<ConversionResult> perform({
    required String entryValue,
    required String input,
    required String result,
    required bool isInputFocused,
    required bool useHexFormat,
  }) async {
    final index = int.tryParse(entryValue) ?? 27;

    try {
      switch (index) {
        case 0:
          return _base64(input, result, isInputFocused);
        case 1:
          return isInputFocused
              ? ConversionResult(result: TextConverters.unicodeEncode(input))
              : ConversionResult(input: TextConverters.unicodeDecode(result));
        case 2:
          return isInputFocused
              ? ConversionResult(result: TextConverters.urlEncode(input))
              : ConversionResult(input: TextConverters.urlDecode(result));

        case 3:
        case 4:
        case 5:
        case 6:
        case 7:
        case 8:
          return ConversionResult(
            result: TextConverters.hash(input, _hashAlgorithms[index]!),
          );

        case 9:
        case 10:
        case 11:
        case 12:
        case 13:
        case 14:
        case 15:
          return _byteArray(
            input: input,
            result: result,
            forward: isInputFocused,
            useHexFormat: useHexFormat,
            charset: _charsets[index]!,
          );

        case 16:
          return _numberSystem(
            input: input,
            allowedPattern: r'0-9',
            convert: (filtered) => NumberConverters.decimalToBases(filtered),
          );
        case 17:
          return _numberSystem(
            input: input,
            allowedPattern: r'01',
            convert: (filtered) => NumberConverters.binaryToBases(filtered),
          );
        case 18:
          return _numberSystem(
            input: input,
            allowedPattern: r'0-7',
            convert: (filtered) => NumberConverters.octalToBases(filtered),
          );
        case 19:
          return _numberSystem(
            input: input,
            allowedPattern: r'0-9a-fA-F',
            convert: (filtered) => NumberConverters.hexToBases(filtered),
          );
        case 20:
          return _numberSystem(
            input: input,
            allowedPattern: r'0-9a-fA-FxX',
            convert: (filtered) => NumberConverters.hex0xToBases(filtered),
          );

        case 21:
          return _float(
            forward: isInputFocused,
            input: input,
            result: result,
            encode: FloatConverters.encodeBinary,
            decode: FloatConverters.decodeBinary,
          );
        case 22:
          return _float(
            forward: isInputFocused,
            input: input,
            result: result,
            encode: FloatConverters.encodeOctal,
            decode: FloatConverters.decodeOctal,
          );
        case 23:
          return _float(
            forward: isInputFocused,
            input: input,
            result: result,
            encode: FloatConverters.encodeHex,
            decode: FloatConverters.decodeHex,
          );
        case 24:
          return _float(
            forward: isInputFocused,
            input: input,
            result: result,
            encode: FloatConverters.encodeHex0x,
            decode: FloatConverters.decodeHex,
          );
        case 25:
          return _float(
            forward: isInputFocused,
            input: input,
            result: result,
            encode: FloatConverters.encodeHex0xPadded,
            decode: FloatConverters.decodeHex,
          );

        case 26:
          return isInputFocused
              ? ConversionResult(result: ColorConverters.colorToSmaliHex(input))
              : ConversionResult(
                  input: ColorConverters.hexNumberToArgbHex(result) ??
                      (throw const FormatException('Invalid color hex')),
                );

        case 27:
          return _encrypt(
            forward: isInputFocused,
            input: input,
            result: result,
            encrypt: (text, key) => CryptoConverters.secureEncrypt(text, key),
            decrypt: (text, key) => CryptoConverters.secureDecrypt(text, key),
          );

        case 28:
          if (isInputFocused) {
            final color = ColorConverters.parseColor(
              ColorConverters.normalizeHex(input),
            );
            if (color == null) throw const FormatException('Invalid color');
            return ConversionResult(
              result: ColorConverters.toSigned32(color).toString(),
            );
          }
          final decimal = int.tryParse(result.trim());
          if (decimal == null) throw const FormatException('Invalid decimal color');
          return ConversionResult(input: ColorConverters.toPackedHex(decimal));

        case 29:
          if (isInputFocused) {
            final color = ColorConverters.parseColor(
              ColorConverters.normalizeHex(input),
            );
            if (color == null) throw const FormatException('Invalid color');
            return ConversionResult(
              result: '${ColorConverters.alpha(color)},'
                  '${ColorConverters.red(color)},'
                  '${ColorConverters.green(color)},'
                  '${ColorConverters.blue(color)}',
            );
          }
          if (!ColorConverters.isValidRgba(result)) {
            throw const FormatException('Invalid RGBA format');
          }
          final color = ColorConverters.rgbStringToArgb(result);
          return ConversionResult(input: ColorConverters.toPackedHex(color));

        case 30:
          return _encrypt(
            forward: isInputFocused,
            input: input,
            result: result,
            encrypt: (text, key) async =>
                CryptoConverters.fastEncrypt(text, key) ??
                (throw const FormatException('Encryption failed')),
            decrypt: (text, key) async =>
                CryptoConverters.fastDecrypt(text, key) ??
                (throw const FormatException('Decryption failed')),
          );

        case 31:
          return isInputFocused
              ? ConversionResult(result: TextConverters.textToBinary(input))
              : ConversionResult(input: TextConverters.binaryToText(result));

        case 32:
          final filtered = input.replaceAll(RegExp(r'[^01\s+\-]'), '');
          return ConversionResult(
            input: filtered,
            result: NumberConverters.calculateBinary(filtered),
            readOnlyResult: true,
          );

        default:
          return const ConversionResult();
      }
    } catch (e) {
      return ConversionResult(error: e.toString());
    }
  }

  // ---------------- case helpers ----------------

  static ConversionResult _base64(String input, String result, bool forward) {
    if (forward) {
      return ConversionResult(result: base64.encode(utf8.encode(input)));
    }
    final bytes = base64.decode(result.trim());
    return ConversionResult(input: utf8.decode(bytes, allowMalformed: true));
  }

  static ConversionResult _byteArray({
    required String input,
    required String result,
    required bool forward,
    required bool useHexFormat,
    required String charset,
  }) {
    if (forward) {
      final bytes = StringCodecs.encode(input, charset);
      final encoded = useHexFormat
          ? TextConverters.groupHexPairs(TextConverters.bytesToCompactHex(bytes))
          : TextConverters.bytesTo0xHex(bytes, '\n');
      return ConversionResult(result: encoded);
    }

    final List<int> bytes;
    if (useHexFormat) {
      final hex = result.replaceAll(RegExp(r'[^A-Fa-f0-9]'), '');
      bytes = TextConverters.hexToBytes(hex);
    } else {
      final lines = result.split('\n');
      while (lines.isNotEmpty && lines.last.isEmpty) {
        lines.removeLast();
      }
      bytes = TextConverters.linesToBytes(lines);
    }
    return ConversionResult(input: StringCodecs.decode(bytes, charset));
  }

  static ConversionResult _numberSystem({
    required String input,
    required String allowedPattern,
    required String Function(String) convert,
  }) {
    final filtered = input.replaceAll(RegExp('[^$allowedPattern]'), '');
    if (filtered.isEmpty) {
      throw const FormatException('Invalid number');
    }
    return ConversionResult(
      input: filtered,
      result: convert(filtered),
      readOnlyResult: true,
    );
  }

  static ConversionResult _float({
    required bool forward,
    required String input,
    required String result,
    required String Function(String) encode,
    required String Function(String) decode,
  }) {
    return forward
        ? ConversionResult(result: encode(input))
        : ConversionResult(input: decode(result));
  }

  static Future<ConversionResult> _encrypt({
    required bool forward,
    required String input,
    required String result,
    required Future<String> Function(String, String) encrypt,
    required Future<String> Function(String, String) decrypt,
  }) async {
    final alias = await PasswordManager.getPrivateKey();

    if (!forward) {
      return ConversionResult(input: await decrypt(result, alias));
    }
    // Java intentionally skips encryption for empty input.
    if (input.isEmpty) return const ConversionResult();
    return ConversionResult(result: await encrypt(input, alias));
  }
}
