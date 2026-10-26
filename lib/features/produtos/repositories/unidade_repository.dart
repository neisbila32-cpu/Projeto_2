import 'package:sqflite/sqflite.dart';

import 'package:projeto_2/core/database/app_database.dart';
import 'package:projeto_2/core/utils/app_exception.dart';
import 'package:projeto_2/features/produtos/models/unidade.dart';

class UnidadeRepository {
  UnidadeRepository(this._appDb);

  final AppDatabase _appDb;

  Future<List<Unidade>> listar({bool incluirInativas = false}) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'unidades',
      where: incluirInativas ? null : 'ativa = 1',
      orderBy: 'nome COLLATE NOCASE',
    );
    return rows.map(Unidade.fromMap).toList();
  }

  Future<void> criar({
    required String sigla,
    required String nome,
    required bool fracionavel,
  }) async {
    final db = await _appDb.database;
    final siglaLimpa = sigla.trim();
    final nomeLimpo = nome.trim();
    if (siglaLimpa.isEmpty || nomeLimpo.isEmpty) {
      throw const AppException('Informe a sigla e o nome da unidade.');
    }
    if (siglaLimpa.length > 10 || siglaLimpa.contains(' ')) {
      throw const AppException(
        'A sigla deve ter até 10 caracteres e não pode ter espaços.',
      );
    }
    final rows = await db.query('unidades', columns: ['sigla']);
    final existe = rows.any(
      (r) => (r['sigla'] as String).toLowerCase() == siglaLimpa.toLowerCase(),
    );
    if (existe) {
      throw const AppException('Já existe uma unidade com esta sigla.');
    }
    await db.insert('unidades', {
      'sigla': siglaLimpa,
      'nome': nomeLimpo,
      'fracionavel': fracionavel ? 1 : 0,
      'ativa': 1,
    });
  }

  Future<void> definirAtiva(int id, bool ativa) async {
    final db = await _appDb.database;
    if (!ativa) {
      final r = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM produtos WHERE unidade_id = ? AND ativo = 1',
        [id],
      );
      if ((Sqflite.firstIntValue(r) ?? 0) > 0) {
        throw const AppException(
          'Existem produtos ativos que usam esta unidade. Não é possível inativá-la.',
        );
      }
    }
    await db.update(
      'unidades',
      {'ativa': ativa ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}