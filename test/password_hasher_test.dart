import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_2/core/utils/password_hasher.dart';

void main() {
  test('hash e verificaÃ§Ã£o de senha', () async {
    final salt = PasswordHasher.generateSalt();
    final hash = await PasswordHasher.hash('minhaSenha123', salt);
    expect(await PasswordHasher.verify('minhaSenha123', salt, hash), isTrue);
    expect(await PasswordHasher.verify('outraSenha', salt, hash), isFalse);
  });

  test('cÃ³digo de recuperaÃ§Ã£o tem o formato XXXX-XXXX-XXXX', () {
    final codigo = PasswordHasher.generateRecoveryCode();
    expect(
      RegExp(r'^[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$').hasMatch(codigo),
      isTrue,
    );
    expect(PasswordHasher.normalizeRecoveryCode(codigo).length, 12);
  });
}
