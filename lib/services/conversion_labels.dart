/// Input / output labels used by the conversion detail screen.
///
/// Port of `UIInitializer.getInputNameForOption` / `getOutputNameForOption`.
class ConversionLabels {
  ConversionLabels._();

  static const Map<int, List<String>> _labels = {
    0: ['Plain Text / Data', 'Base64'],
    1: ['Plain Text', r'Unicode (\uXXXX)'],
    2: ['Plain Text', 'URL Encoded Text'],
    3: ['Plain Text', 'MD5 Hash'],
    4: ['Plain Text', 'SHA-1 Hash'],
    5: ['Plain Text', 'SHA-224 Hash'],
    6: ['Plain Text', 'SHA-256 Hash'],
    7: ['Plain Text', 'SHA-384 Hash'],
    8: ['Plain Text', 'SHA-512 Hash'],
    9: ['Plain Text', 'UTF-8 Byte Array'],
    10: ['Plain Text', 'UTF-16 Byte Array'],
    11: ['Plain Text', 'UTF-16LE Byte Array'],
    12: ['Plain Text', 'UTF-16BE Byte Array'],
    13: ['Plain Text', 'US-ASCII Byte Array'],
    14: ['Plain Text', 'ISO-8859-1 Byte Array'],
    15: ['Plain Text', 'CP1251 Byte Array'],
    16: ['Decimal (Base-10)', 'Binary, Octal, Hexadecimal'],
    17: ['Binary (Base-2)', 'Decimal, Octal, Hexadecimal'],
    18: ['Octal (Base-8)', 'Decimal, Binary, Hexadecimal'],
    19: ['Hexadecimal (0x0)', 'Decimal, Binary, Octal'],
    20: ['Hexadecimal (0x00000000)', 'Decimal, Binary, Octal'],
    21: ['Decimal Float', 'Float Binary (IEEE 754)'],
    22: ['Decimal Float', 'Float Octal'],
    23: ['Decimal Float', 'Float Hexadecimal'],
    24: ['Decimal Float', 'Float Hex (0x0)'],
    25: ['Decimal Float', 'Float Hex (0x00000000)'],
    26: ['Color Hex (#AARRGGBB)', 'Color Decimal & RGB'],
    27: ['Decrypted Text', 'Encrypted Text'],
    28: ['Color Decimal', 'Color Hex & RGB'],
    29: ['Color ARGB', 'Color Hex & Decimal'],
    30: ['Decrypted Text', 'Encrypted Text'],
    31: ['Plain Text', 'Binary Bitstream'],
    32: ['Binary Expression', 'Binary Result'],
  };

  static String inputLabel(int index) => _labels[index]?.first ?? 'Input';

  static String outputLabel(int index) => _labels[index]?.last ?? 'Result';

  static bool isColorMode(int index) => index == 26 || index == 28 || index == 29;

  static bool isByteArrayMode(int index) => index >= 9 && index <= 15;

  static bool isNumberSystem(int index) => index >= 16 && index <= 20;

  static bool isEncryptionMode(int index) => index == 27 || index == 30;
}
