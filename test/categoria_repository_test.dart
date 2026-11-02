import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:projeto_2/core/database/app_database.dart';
import 'package:projeto_2/core/utils/app_exception.dart';
import 'package:projeto_2/features/produtos/repositories/categoria_repository.dart';
import 'cenarios/apoio/banco_teste.dart';

void main() {
  late Database db;
  late CategoriaRepository repository;

  setUpAll(() async {
    await abrirBancoEmMemoria();
    db = await AppDatabase.instance.database;
    repository = CategoriaRepository(AppDatabase.instance);
  });

  test('cria categoria e a nova categoria aparece na listagem', () async {
    const nome = 'Categoria criada no teste';
    await repository.criar(nome);
    expect((await repository.listar()).any((c) => c.nome == nome), isTrue);
  });

  test('exclui categoria vazia', () async {
    final id = await db.insert('categorias', {'nome': 'Categoria vazia'});
    await repository.excluir(id);
    expect(
      await db.query('categorias', where: 'id = ?', whereArgs: [id]),
      isEmpty,
    );
  });

  test(
    'bloqueia categoria com produto associado e preserva os registros',
    () async {
      final usuarioId = await db.insert('usuarios', {
        'nome': 'Admin',
        'login': 'admin_categoria',
        'senha_hash': 'hash',
        'senha_salt': 'salt',
        'perfil': 'admin',
        'ativo': 1,
        'criado_em': DateTime.now().toIso8601String(),
      });
      final categoriaId = await db.insert('categorias', {
        'nome': 'Categoria vinculada',
      });
      final unidade = (await db.query('unidades', limit: 1)).first;
      final produtoId = await db.insert('produtos', {
        'nome': 'Produto ligado à categoria',
        'categoria_id': categoriaId,
        'unidade_id': unidade['id'],
        'saldo': 0,
        'ativo': 0,
        'criado_em': DateTime.now().toIso8601String(),
        'criado_por': usuarioId,
      });

      await expectLater(
        repository.excluir(categoriaId),
        throwsA(isA<AppException>()),
      );
      expect(
        await db.query('categorias', where: 'id = ?', whereArgs: [categoriaId]),
        hasLength(1),
      );
      expect(
        await db.query('produtos', where: 'id = ?', whereArgs: [produtoId]),
        hasLength(1),
      );
    },
  );
}
