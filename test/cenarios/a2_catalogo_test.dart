import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:projeto_2/core/database/app_database.dart';
import 'package:projeto_2/features/produtos/repositories/catalogo_inicial_repository.dart';
import 'package:projeto_2/features/produtos/repositories/produto_repository.dart';
import 'package:projeto_2/features/produtos/repositories/unidade_repository.dart';
import 'package:projeto_2/features/produtos/repositories/categoria_repository.dart';
import 'apoio/banco_teste.dart';

void main() {
  group('A2 Catálogo', () {
    late CatalogoInicialRepository catRepo;
    late ProdutoRepository prodRepo;
    late Database db;
    late int usuarioId;

    setUpAll(() async {
      await abrirBancoEmMemoria();
      db = await AppDatabase.instance.database;
      catRepo = CatalogoInicialRepository(AppDatabase.instance);
      prodRepo = ProdutoRepository(AppDatabase.instance);
    });

    setUp(() async {
      await limparDados(db);
      // usuário para created_por do importar()
      final resultado = await db.insert('usuarios', {
        'nome': 'Admin',
        'login': 'admin',
        'senha_hash': 'hash',
        'senha_salt': 'salt',
        'perfil': 'admin',
        'ativo': 1,
        'criado_em': DateTime.now().toIso8601String(),
      });
      usuarioId = resultado;
    });

    test('importar o catálogo cria 91 produtos', () async {
      final resultado = await catRepo.importar(usuarioId);
      expect(resultado.criados, 91);
      expect(resultado.ignorados, 0);
    });

    test('importar de novo cria 0 e ignora 91', () async {
      await catRepo.importar(usuarioId);
      final resultado = await catRepo.importar(usuarioId);
      expect(resultado.criados, 0);
      expect(resultado.ignorados, 91);
    });

    test('todos com saldo 0 e nenhuma movimentação criada', () async {
      await catRepo.importar(usuarioId);
      final produtos = await prodRepo.listar();
      expect(produtos.length, 91);
      for (final p in produtos) {
        expect(p.saldo, 0);
      }
      final mov = await db.rawQuery('SELECT COUNT(*) AS n FROM movimentacoes');
      expect((Sqflite.firstIntValue(mov) ?? 0), 0);
    });

    test('a unidade fr existe', () async {
      await catRepo.importar(usuarioId);
      final rows = await db.query('unidades', where: 'sigla = ?', whereArgs: ['fr']);
      expect(rows.isNotEmpty, isTrue);
    });

    test('as 6 categorias do catálogo existem e ficam ativas', () async {
      await catRepo.importar(usuarioId);
      final categoriasCatalogo = [
        'Proteínas', 'Mercearia', 'Laticínios e derivados',
        'Hortifrutigranjeiros', 'Descartáveis e utensílios', 'Material de limpeza',
      ];
      for (final nome in categoriasCatalogo) {
        final rows = await db.query(
          'categorias', where: 'nome = ?', whereArgs: [nome],
        );
        expect(rows.isNotEmpty, isTrue, reason: 'categoria $nome não existe');
        expect(rows.first['ativa'] as int, 1, reason: 'categoria $nome não está ativa');
      }
    });

    test('as categorias de fábrica sem produtos ficam inativas', () async {
      await catRepo.importar(usuarioId);
      // As 4 categorias de fábrica que não têm produto do catálogo ficam inativas.
      final fabricas = [
        'Gêneros secos', 'Perecíveis', 'Hortifrúti', 'Descartáveis',
      ];
      for (final nome in fabricas) {
        final rows = await db.query(
          'categorias', where: 'nome = ?', whereArgs: [nome],
        );
        if (rows.isNotEmpty) {
          expect(rows.first['ativa'] as int, 0, reason: '$nome deveria estar inativa');
        }
      }
    });
  });
}
