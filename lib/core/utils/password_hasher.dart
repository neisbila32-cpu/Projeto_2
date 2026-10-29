import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';

/// Hash de senha com PBKDF2-HMAC-SHA256 + salt aleatório.
class PasswordHasher {
  PasswordHasher._();

  static const int _iterations = 100000;
  static const int _bits = 256;
  static final Random _random = Random.secure();

  static String generateSalt([int length = 16]) {
    final bytes = List<int>.generate(length, (_) => _random.nextInt(256));
    return base64Encode(bytes);
  }

  static Future<String> hash(String password, String salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _iterations,
      bits: _bits,
    );
    final key = await pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: base64Decode(salt),
    );
    final bytes = await key.extractBytes();
    return base64Encode(bytes);
  }

  static Future<bool> verify(
    String password,
    String salt,
    String expectedHash,
  ) async {
    final computed = await hash(password, salt);
    return _constantTimeEquals(computed, expectedHash);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String generateRecoveryCode() {
    final chars = List<String>.generate(
      12,
      (_) => _alphabet[_random.nextInt(_alphabet.length)],
    );
    return '${chars.sublist(0, 4).join()}-'
        '${chars.sublist(4, 8).join()}-'
        '${chars.sublist(8, 12).join()}';
  }

  static String normalizeRecoveryCode(String input) =>
      input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}
