import 'package:sqflite/sqflite.dart';

import 'package:projeto_2/core/database/app_database.dart';
import 'package:projeto_2/core/utils/app_exception.dart';
import 'package:projeto_2/core/utils/texto_utils.dart';
import 'package:projeto_2/features/produtos/models/categoria.dart';

class CategoriaRepository {
  CategoriaRepository(this._appDb);

  final AppDatabase _appDb;

  Future<List<Categoria>> listar({bool incluirInativas = false}) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'categorias',
      where: incluirInativas ? null : 'ativa = 1',
      orderBy: 'nome COLLATE NOCASE',
    );
    return rows.map(Categoria.fromMap).toList();
  }

  Future<void> criar(String nome) async {
    final db = await _appDb.database;
    final nomeLimpo = nome.trim();
    if (nomeLimpo.isEmpty) {
      throw const AppException('Informe o nome da categoria.');
    }
    await _validarNomeUnico(db, nomeLimpo);
    await db.insert('categorias', {'nome': nomeLimpo, 'ativa': 1});
  }

  Future<void> renomear(int id, String nome) async {
    final db = await _appDb.database;
    final nomeLimpo = nome.trim();
    if (nomeLimpo.isEmpty) {
      throw const AppException('Informe o nome da categoria.');
    }
    await _validarNomeUnico(db, nomeLimpo, ignorarId: id);
    await db.update(
      'categorias',
      {'nome': nomeLimpo},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> definirAtiva(int id, bool ativa) async {
    final db = await _appDb.database;
    if (!ativa) {
      final r = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM produtos WHERE categoria_id = ? AND ativo = 1',
        [id],
      );
      if ((Sqflite.firstIntValue(r) ?? 0) > 0) {
        throw const AppException(
          'Existem produtos ativos nesta categoria. Mude-os de categoria antes de inativá-la.',
        );
      }
    }
    await db.update(
      'categorias',
      {'ativa': ativa ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> _validarNomeUnico(
    DatabaseExecutor db,
    String nome, {
    int? ignorarId,
  }) async {
    final rows = await db.query('categorias', columns: ['id', 'nome']);
    final alvo = TextoUtils.normalizar(nome);
    for (final r in rows) {
      if (r['id'] == ignorarId) continue;
      if (TextoUtils.normalizar(r['nome'] as String) == alvo) {
        throw const AppException('Já existe uma categoria com este nome.');
      }
    }
  }
}