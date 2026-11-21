import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:projeto_2/core/database/app_database.dart';
import 'package:projeto_2/core/utils/app_exception.dart';
import 'package:projeto_2/features/produtos/repositories/unidade_repository.dart';
import 'cenarios/apoio/banco_teste.dart';

void main() {
  late Database db;
  late UnidadeRepository repository;

  setUpAll(() async {
    await abrirBancoEmMemoria();
    db = await AppDatabase.instance.database;
    repository = UnidadeRepository(AppDatabase.instance);
  });

  test('exclui unidade sem produto vinculado', () async {
    final id = await db.insert('unidades', {
      'sigla': 'cxvazia',
      'nome': 'Caixa vazia',
      'fracionavel': 0,
      'ativa': 1,
    });

    await repository.excluir(id);

    expect(
      await db.query('unidades', where: 'id = ?', whereArgs: [id]),
      isEmpty,
    );
    expect(
      Sqflite.firstIntValue(await db.rawQuery('PRAGMA user_version')),
      AppDatabase.versaoAtual,
    );
  });

  test('bloqueia exclusão de unidade usada e orienta manter inativa', () async {
    final usuarioId = await db.insert('usuarios', {
      'nome': 'Admin',
      'login': 'admin_unidade',
      'senha_hash': 'hash',
      'senha_salt': 'salt',
      'perfil': 'admin',
      'ativo': 1,
      'criado_em': DateTime.now().toIso8601String(),
    });
    final unidade = (await db.query('unidades', limit: 1)).single;
    final produtoId = await db.insert('produtos', {
      'nome': 'Produto com unidade',
      'categoria_id': (await db.query('categorias', limit: 1)).single['id'],
      'unidade_id': unidade['id'],
      'saldo': 0,
      'ativo': 0,
      'criado_em': DateTime.now().toIso8601String(),
      'criado_por': usuarioId,
    });

    await expectLater(
      repository.excluir(unidade['id'] as int),
      throwsA(
        isA<AppException>().having(
          (erro) => erro.message,
          'mensagem',
          contains('Mantenha-a inativa'),
        ),
      ),
    );
    expect(
      await db.query('unidades', where: 'id = ?', whereArgs: [unidade['id']]),
      hasLength(1),
    );
    expect(
      await db.query('produtos', where: 'id = ?', whereArgs: [produtoId]),
      hasLength(1),
    );
  });
}
