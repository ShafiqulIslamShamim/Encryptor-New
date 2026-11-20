import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/ecb.dart';
import 'package:pointycastle/digests/sha1.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/block/modes/gcm.dart';
import 'package:pointycastle/paddings/pkcs7.dart';
import 'package:pointycastle/padded_block_cipher/padded_block_cipher_impl.dart';

/// Port of Java `FastEncryption` and `SecureCrypto`.
///
/// Both algorithms are kept byte-compatible with the Android implementation.
class CryptoConverters {
  CryptoConverters._();

  // ---------------- FastEncryption (converter value 30) ----------------

  /// Java `FastEncryption.getSecreteKey`: SHA-1(password UTF-8), first 16 bytes.
  static Uint8List _fastKey(String password) {
    final sha1 = SHA1Digest()..reset();
    final digest = sha1.process(Uint8List.fromList(utf8.encode(password)));
    return Uint8List.fromList(digest.sublist(0, 16));
  }

  /// Java `getStrForEncryption`: AES/ECB/PKCS5Padding, standard Base64,
  /// no salt, no IV, deterministic.
  static String? fastEncrypt(String plaintext, String password) {
    try {
      final cipher = PaddedBlockCipherImpl(PKCS7Padding(), ECBBlockCipher(AESEngine()));
      cipher.init(
        true,
        PaddedBlockCipherParameters<KeyParameter, Null>(
          KeyParameter(_fastKey(password)),
          null,
        ),
      );
      final encrypted = cipher.process(Uint8List.fromList(utf8.encode(plaintext)));
      return base64.encode(encrypted);
    } catch (_) {
      return null;
    }
  }

  /// Java `getStrForDecryption`.
  static String? fastDecrypt(String ciphertext, String password) {
    try {
      final cipher = PaddedBlockCipherImpl(PKCS7Padding(), ECBBlockCipher(AESEngine()));
      cipher.init(
        false,
        PaddedBlockCipherParameters<KeyParameter, Null>(
          KeyParameter(_fastKey(password)),
          null,
        ),
      );
      final decrypted = cipher.process(
        base64.decode(ciphertext.replaceAll(RegExp(r'\s'), '')),
      );
      return utf8.decode(decrypted, allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  // ---------------- SecureCrypto (converter value 27) ----------------

  static const int gcmTagLength = 128; // bits
  static const int saltLength = 16;
  static const int ivLength = 12;
  static const int keyLength = 256; // bits
  static const int iterationCount = 1000;
  static const int chunkSize = 16384;

  static Uint8List? _cachedKey;
  static Uint8List? _cachedSalt;
  static String? _cachedPassword;

  /// Java `SecureCrypto.getSecretKey`: PBKDF2-HMAC-SHA256, 1000 iterations,
  /// 256-bit key. The cache also checks the password: the Android version only
  /// compared the salt, which could return the old key after a key rotation.
  static Uint8List deriveKey(String password, Uint8List salt) {
    if (_cachedKey != null &&
        _cachedSalt != null &&
        _cachedPassword == password &&
        _bytesEqual(_cachedSalt!, salt)) {
      return _cachedKey!;
    }

    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterationCount, keyLength ~/ 8));
    final key = pbkdf2.process(Uint8List.fromList(utf8.encode(password)));

    _cachedKey = Uint8List.fromList(key);
    _cachedSalt = Uint8List.fromList(salt);
    _cachedPassword = password;
    return _cachedKey!;
  }

  /// Java `SecureCrypto.encryptData`.
  ///
  /// Wire format (before Base64.DEFAULT): `[salt][IV|ct+tag]*`. A fresh salt
  /// and a fresh 12-byte IV per 16 KB plaintext chunk are generated.
  static Future<String> secureEncrypt(String data, String password) async {
    final random = Random.secure();
    final salt = _randomBytes(random, saltLength);
    final key = deriveKey(password, salt);

    final dataBytes = utf8.encode(data);
    final output = BytesBuilder()
      ..add(salt);

    int offset = 0;
    while (offset < dataBytes.length) {
      final length = min(chunkSize, dataBytes.length - offset);
      final chunk = Uint8List.fromList(dataBytes.sublist(offset, offset + length));
      offset += length;

      final iv = _randomBytes(random, ivLength);
      final gcm = GCMBlockCipher(AESEngine())
        ..init(true, AEADParameters(KeyParameter(key), gcmTagLength, iv, Uint8List(0)));
      final encrypted = gcm.process(chunk);

      output
        ..add(iv)
        ..add(encrypted);
    }

    return _androidBase64Encode(output.takeBytes());
  }

  /// Java `SecureCrypto.decryptData`.
  static Future<String> secureDecrypt(String encryptedData, String password) async {
    final decoded = base64.decode(encryptedData.replaceAll(RegExp(r'\s'), ''));
    if (decoded.length < saltLength) {
      throw const FormatException('Invalid encrypted data format');
    }

    final salt = Uint8List.fromList(decoded.sublist(0, saltLength));
    final key = deriveKey(password, salt);

    final plain = BytesBuilder();
    int offset = saltLength;
    while (offset < decoded.length) {
      if (offset + ivLength > decoded.length) {
        throw const FormatException('Invalid encrypted data format');
      }
      final iv = Uint8List.fromList(decoded.sublist(offset, offset + ivLength));
      offset += ivLength;

      final cipherTextLength = min(chunkSize + 16, decoded.length - offset);
      if (cipherTextLength <= 0) {
        throw const FormatException('Invalid ciphertext length');
      }
      final cipherText = Uint8List.fromList(
        decoded.sublist(offset, offset + cipherTextLength),
      );
      offset += cipherTextLength;

      final gcm = GCMBlockCipher(AESEngine())
        ..init(false, AEADParameters(KeyParameter(key), gcmTagLength, iv, Uint8List(0)));
      plain.add(gcm.process(cipherText));
    }

    return utf8.decode(plain.takeBytes(), allowMalformed: true);
  }

  /// `android.util.Base64.DEFAULT` wraps at 76 characters and appends a
  /// trailing newline. Standard `base64.encode` does not, so replicate it for
  /// compatibility with ciphertext produced by the Android app.
  static String _androidBase64Encode(List<int> bytes) {
    final encoded = base64.encode(bytes);
    final buffer = StringBuffer();
    for (int i = 0; i < encoded.length; i += 76) {
      buffer
        ..write(encoded.substring(i, min(i + 76, encoded.length)))
        ..write('\n');
    }
    return buffer.toString();
  }

  static Uint8List _randomBytes(Random random, int length) {
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
