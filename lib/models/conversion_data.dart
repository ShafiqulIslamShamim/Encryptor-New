import 'package:material_ui/material_ui.dart';

/// A single conversion option shown on the dashboard.
///
/// Mirrors the Java `ConversionItem` model. [entryValue] is the string key
/// (0..32) used by the conversion engine to pick the right algorithm, exactly
/// like the `converter_select` preference value in the original app.
class ConversionItem {
  final String entryValue;
  final String title;
  final String subtitle;
  final IconData icon;
  final String categoryName;

  const ConversionItem({
    required this.entryValue,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.categoryName,
  });
}

/// A collapsible group of conversion options.
///
/// Mirrors the Java `ConversionCategory` model. Categories start expanded,
/// just like `isExpanded = true` in the original.
class ConversionCategory {
  final String name;
  final String description;
  final IconData icon;
  final List<ConversionItem> items;
  bool isExpanded;

  ConversionCategory({
    required this.name,
    required this.description,
    required this.icon,
    required this.items,
    this.isExpanded = true,
  });

  bool hasSelectedValue(String selectedValue) {
    return items.any((item) => item.entryValue == selectedValue);
  }
}

/// Static catalog of every conversion, ported from Java `ConversionData`.
class ConversionData {
  static List<ConversionCategory> getCategories() {
    return [
      // Category 1: Security & Encryption
      ConversionCategory(
        name: 'Security & Encryption',
        description: 'AES cipher algorithms with secure key derivation',
        icon: Icons.security,
        items: const [
          ConversionItem(
            entryValue: '27',
            title: 'Encrypt & decrypt (slow but secured)',
            subtitle: 'AES-GCM encryption with Argon2 password hashing',
            icon: Icons.lock,
            categoryName: 'Security & Encryption',
          ),
          ConversionItem(
            entryValue: '30',
            title: 'Encrypt & decrypt (fast but less secured)',
            subtitle: 'Fast AES encryption with simple password key',
            icon: Icons.password,
            categoryName: 'Security & Encryption',
          ),
        ],
      ),

      // Category 2: Text Encodings & Ciphers
      ConversionCategory(
        name: 'Text Encodings & Ciphers',
        description: 'Encode, decode & transform plain text formats',
        icon: Icons.code,
        items: const [
          ConversionItem(
            entryValue: '0',
            title: 'Base64',
            subtitle: 'Standard Base64 string encoding and decoding',
            icon: Icons.code,
            categoryName: 'Text Encodings & Ciphers',
          ),
          ConversionItem(
            entryValue: '1',
            title: 'Unicode',
            subtitle: 'Convert text characters to Unicode escape sequences (\\uXXXX)',
            icon: Icons.code,
            categoryName: 'Text Encodings & Ciphers',
          ),
          ConversionItem(
            entryValue: '2',
            title: 'URL encoding',
            subtitle: 'Percent-encode special web URL characters',
            icon: Icons.code,
            categoryName: 'Text Encodings & Ciphers',
          ),
          ConversionItem(
            entryValue: '31',
            title: 'Text Binary',
            subtitle: 'Convert text characters to binary bitstream representation',
            icon: Icons.code,
            categoryName: 'Text Encodings & Ciphers',
          ),
        ],
      ),

      // Category 3: Cryptographic Hashes
      ConversionCategory(
        name: 'Cryptographic Hashes',
        description: 'One-way digest and checksum generator functions',
        icon: Icons.fingerprint,
        items: const [
          ConversionItem(
            entryValue: '3',
            title: 'MD5',
            subtitle: '128-bit Message-Digest algorithm hash',
            icon: Icons.shield,
            categoryName: 'Cryptographic Hashes',
          ),
          ConversionItem(
            entryValue: '4',
            title: 'SHA-1',
            subtitle: '160-bit Secure Hash Algorithm digest',
            icon: Icons.shield,
            categoryName: 'Cryptographic Hashes',
          ),
          ConversionItem(
            entryValue: '5',
            title: 'SHA-224',
            subtitle: '224-bit Secure Hash Algorithm digest',
            icon: Icons.shield,
            categoryName: 'Cryptographic Hashes',
          ),
          ConversionItem(
            entryValue: '6',
            title: 'SHA-256',
            subtitle: '256-bit Secure Hash Algorithm digest',
            icon: Icons.shield,
            categoryName: 'Cryptographic Hashes',
          ),
          ConversionItem(
            entryValue: '7',
            title: 'SHA-384',
            subtitle: '384-bit Secure Hash Algorithm digest',
            icon: Icons.shield,
            categoryName: 'Cryptographic Hashes',
          ),
          ConversionItem(
            entryValue: '8',
            title: 'SHA-512',
            subtitle: '512-bit Secure Hash Algorithm digest',
            icon: Icons.shield,
            categoryName: 'Cryptographic Hashes',
          ),
        ],
      ),

      // Category 4: Byte Array & Character Sets
      ConversionCategory(
        name: 'Byte Array & Character Sets',
        description: 'Convert raw bytes using standard character encodings',
        icon: Icons.grid_view,
        items: const [
          ConversionItem(
            entryValue: '9',
            title: 'Array (UTF-8)',
            subtitle: 'Byte array representation in UTF-8 format',
            icon: Icons.memory,
            categoryName: 'Byte Array & Character Sets',
          ),
          ConversionItem(
            entryValue: '10',
            title: 'Array (UTF-16)',
            subtitle: 'Byte array representation in UTF-16 format',
            icon: Icons.memory,
            categoryName: 'Byte Array & Character Sets',
          ),
          ConversionItem(
            entryValue: '11',
            title: 'Array (UTF-16LE)',
            subtitle: 'Byte array in UTF-16 Little Endian format',
            icon: Icons.memory,
            categoryName: 'Byte Array & Character Sets',
          ),
          ConversionItem(
            entryValue: '12',
            title: 'Array (UTF-16BE)',
            subtitle: 'Byte array in UTF-16 Big Endian format',
            icon: Icons.memory,
            categoryName: 'Byte Array & Character Sets',
          ),
          ConversionItem(
            entryValue: '13',
            title: 'Array (US-ASCII)',
            subtitle: 'Byte array in 7-bit US-ASCII format',
            icon: Icons.memory,
            categoryName: 'Byte Array & Character Sets',
          ),
          ConversionItem(
            entryValue: '14',
            title: 'Array (ISO-8859-1)',
            subtitle: 'Byte array in Latin-1 character set',
            icon: Icons.memory,
            categoryName: 'Byte Array & Character Sets',
          ),
          ConversionItem(
            entryValue: '15',
            title: 'Array (CP1251)',
            subtitle: 'Byte array in Cyrillic CP1251 code page',
            icon: Icons.memory,
            categoryName: 'Byte Array & Character Sets',
          ),
        ],
      ),

      // Category 5: Number Systems & Math
      ConversionCategory(
        name: 'Number Systems & Math',
        description: 'Convert between binary, octal, decimal & hex',
        icon: Icons.calculate,
        items: const [
          ConversionItem(
            entryValue: '32',
            title: 'Binary Addition & Subtraction',
            subtitle: 'Perform arithmetic calculations on binary numbers',
            icon: Icons.calculate,
            categoryName: 'Number Systems & Math',
          ),
          ConversionItem(
            entryValue: '16',
            title: 'Decimal to Binary, Octal, Hexadecimal',
            subtitle: 'Convert integer base-10 to other bases',
            icon: Icons.calculate,
            categoryName: 'Number Systems & Math',
          ),
          ConversionItem(
            entryValue: '17',
            title: 'Binary to Decimal, Octal, Hexadecimal',
            subtitle: 'Convert base-2 binary string to other bases',
            icon: Icons.calculate,
            categoryName: 'Number Systems & Math',
          ),
          ConversionItem(
            entryValue: '18',
            title: 'Octal to Decimal, Binary, Hexadecimal',
            subtitle: 'Convert base-8 octal values to other bases',
            icon: Icons.calculate,
            categoryName: 'Number Systems & Math',
          ),
          ConversionItem(
            entryValue: '19',
            title: 'Hex(0x0) to Decimal, Binary, Octal',
            subtitle: 'Convert base-16 short hex values',
            icon: Icons.calculate,
            categoryName: 'Number Systems & Math',
          ),
          ConversionItem(
            entryValue: '20',
            title: 'Hex(0x00000000) to Decimal, Binary, Octal',
            subtitle: 'Convert base-16 32-bit padded hex values',
            icon: Icons.calculate,
            categoryName: 'Number Systems & Math',
          ),
        ],
      ),

      // Category 6: Floating Point Encodings
      ConversionCategory(
        name: 'Floating Point Encodings',
        description: 'IEEE 754 32-bit floating point representations',
        icon: Icons.swap_vert,
        items: const [
          ConversionItem(
            entryValue: '21',
            title: 'Float Binary',
            subtitle: '32-bit single precision IEEE 754 float binary',
            icon: Icons.swap_vert,
            categoryName: 'Floating Point Encodings',
          ),
          ConversionItem(
            entryValue: '22',
            title: 'Float Octal',
            subtitle: '32-bit float octal value representation',
            icon: Icons.swap_vert,
            categoryName: 'Floating Point Encodings',
          ),
          ConversionItem(
            entryValue: '23',
            title: 'Float Hex',
            subtitle: '32-bit float hexadecimal representation',
            icon: Icons.swap_vert,
            categoryName: 'Floating Point Encodings',
          ),
          ConversionItem(
            entryValue: '24',
            title: 'Float Hex (0x0)',
            subtitle: 'Float hex representation with short prefix',
            icon: Icons.swap_vert,
            categoryName: 'Floating Point Encodings',
          ),
          ConversionItem(
            entryValue: '25',
            title: 'Float Hex (0x00000000)',
            subtitle: 'Float hex representation with 8-digit padded prefix',
            icon: Icons.swap_vert,
            categoryName: 'Floating Point Encodings',
          ),
        ],
      ),

      // Category 7: Color Converters
      ConversionCategory(
        name: 'Color Converters',
        description: 'Convert between Hex, Decimal, and ARGB color codes',
        icon: Icons.palette,
        items: const [
          ConversionItem(
            entryValue: '26',
            title: 'Color Hex',
            subtitle: 'Convert color hexadecimal codes (#AARRGGBB)',
            icon: Icons.palette,
            categoryName: 'Color Converters',
          ),
          ConversionItem(
            entryValue: '28',
            title: 'Color Decimal',
            subtitle: 'Convert integer decimal color values to RGB',
            icon: Icons.format_color_fill,
            categoryName: 'Color Converters',
          ),
          ConversionItem(
            entryValue: '29',
            title: 'Color ARGB',
            subtitle: 'Convert alpha-red-green-blue color structure',
            icon: Icons.color_lens,
            categoryName: 'Color Converters',
          ),
        ],
      ),
    ];
  }

  /// Returns the first item matching [entryValue], or null.
  static ConversionItem? findItem(String entryValue) {
    for (final category in getCategories()) {
      for (final item in category.items) {
        if (item.entryValue == entryValue) return item;
      }
    }
    return null;
  }
}
