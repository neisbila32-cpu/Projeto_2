import 'package:sqflite/sqflite.dart';
import 'package:projeto_2/core/database/app_database.dart';
import 'package:projeto_2/core/utils/password_hasher.dart';
import 'package:projeto_2/features/auth/models/usuario.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class UsuarioRepository {
  UsuarioRepository(this._appDb);
  final AppDatabase _appDb;

  static const String _msgCredenciais = 'Login ou senha incorretos.';
  static const String _msgRecuperacao =
      'Login ou cÃ³digo de recuperaÃ§Ã£o invÃ¡lido.';

  Future<bool> existeAlgumUsuario() async {
    final db = await _appDb.database;
    final r = await db.rawQuery('SELECT COUNT(*) AS n FROM usuarios');
    return (Sqflite.firstIntValue(r) ?? 0) > 0;
  }

  void _validarSenha(String senha) {
    if (senha.length < 6) {
      throw const AuthException('A senha deve ter pelo menos 6 caracteres.');
    }
  }

  Future<String?> cadastrar({
    required String nome,
    required String login,
    required String senha,
  }) async {
    final db = await _appDb.database;
    final nomeLimpo = nome.trim();
    final loginLimpo = login.trim().toLowerCase();

    if (nomeLimpo.isEmpty) {
      throw const AuthException('Informe o nome.');
    }
    if (loginLimpo.length < 3 || loginLimpo.contains(' ')) {
      throw const AuthException(
        'O login deve ter pelo menos 3 caracteres e nÃ£o pode ter espaÃ§os.',
      );
    }
    _validarSenha(senha);

    final existente = await db.query(
      'usuarios',
      columns: ['id'],
      where: 'login = ?',
      whereArgs: [loginLimpo],
      limit: 1,
    );

    if (existente.isNotEmpty) {
      throw const AuthException('Este login jÃ¡ estÃ¡ em uso.');
    }

    final primeiro = !(await existeAlgumUsuario());
    final salt = PasswordHasher.generateSalt();
    final hash = await PasswordHasher.hash(senha, salt);

    String? codigo;
    String? recupSalt;
    String? recupHash;

    if (primeiro) {
      codigo = PasswordHasher.generateRecoveryCode();
      recupSalt = PasswordHasher.generateSalt();
      recupHash = await PasswordHasher.hash(
        PasswordHasher.normalizeRecoveryCode(codigo),
        recupSalt,
      );
    }

    await db.insert('usuarios', {
      'nome': nomeLimpo,
      'login': loginLimpo,
      'senha_hash': hash,
      'senha_salt': salt,
      'perfil': primeiro ? 'admin' : 'operador',
      'recup_hash': recupHash,
      'recup_salt': recupSalt,
      'ativo': 1,
      'criado_em': DateTime.now().toIso8601String(),
    });

    return codigo;
  }

  Future<Usuario> autenticar({
    required String login,
    required String senha,
  }) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'usuarios',
      where: 'login = ?',
      whereArgs: [login.trim().toLowerCase()],
      limit: 1,
    );

    if (rows.isEmpty) throw const AuthException(_msgCredenciais);

    final row = rows.first;
    final ok = await PasswordHasher.verify(
      senha,
      row['senha_salt'] as String,
      row['senha_hash'] as String,
    );

    if (!ok) throw const AuthException(_msgCredenciais);
    if ((row['ativo'] as int) != 1) {
      throw const AuthException(
        'Este usuÃ¡rio estÃ¡ inativo. Procure o administrador.',
      );
    }

    return Usuario.fromMap(row);
  }

  Future<Usuario?> buscarPorId(int id) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'usuarios',
      where: 'id = ? AND ativo = 1',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Usuario.fromMap(rows.first);
  }

  Future<String> redefinirSenhaComCodigo({
    required String login,
    required String codigo,
    required String novaSenha,
  }) async {
    _validarSenha(novaSenha);
    final db = await _appDb.database;
    final rows = await db.query(
      'usuarios',
      where: "login = ? AND perfil = 'admin' AND ativo = 1",
      whereArgs: [login.trim().toLowerCase()],
      limit: 1,
    );

    if (rows.isEmpty) throw const AuthException(_msgRecuperacao);

    final row = rows.first;
    final recupHash = row['recup_hash'] as String?;
    final recupSalt = row['recup_salt'] as String?;

    if (recupHash == null || recupSalt == null) {
      throw const AuthException(_msgRecuperacao);
    }

    final ok = await PasswordHasher.verify(
      PasswordHasher.normalizeRecoveryCode(codigo),
      recupSalt,
      recupHash,
    );

    if (!ok) throw const AuthException(_msgRecuperacao);

    final novoSalt = PasswordHasher.generateSalt();
    final novoHash = await PasswordHasher.hash(novaSenha, novoSalt);
    final novoCodigo = PasswordHasher.generateRecoveryCode();
    final novoRecupSalt = PasswordHasher.generateSalt();
    final novoRecupHash = await PasswordHasher.hash(
      PasswordHasher.normalizeRecoveryCode(novoCodigo),
      novoRecupSalt,
    );

    await db.update(
      'usuarios',
      {
        'senha_hash': novoHash,
        'senha_salt': novoSalt,
        'recup_hash': novoRecupHash,
        'recup_salt': novoRecupSalt,
      },
      where: 'id = ?',
      whereArgs: [row['id']],
    );

    return novoCodigo;
  }
}
