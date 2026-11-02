import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:projeto_2/core/database/app_database.dart';
import 'package:projeto_2/core/utils/app_exception.dart';
import 'package:projeto_2/features/inventario/repositories/inventario_repository.dart';
import 'package:projeto_2/features/movimentacoes/models/movimentacao.dart';
import 'package:projeto_2/features/movimentacoes/repositories/movimentacao_repository.dart';
import 'package:projeto_2/features/produtos/repositories/produto_repository.dart';
import 'apoio/banco_teste.dart';

void main() {
  group('D1 Inventário físico', () {
    late Database db;
    late InventarioRepository inventarioRepo;
    late MovimentacaoRepository movimentacaoRepo;
    late ProdutoRepository produtoRepo;
    late int usuarioId;
    late int categoriaId;
    late int unidadeKgId;
    late int unidadeUnId;

    setUpAll(() async {
      await abrirBancoEmMemoria();
      db = await AppDatabase.instance.database;
      inventarioRepo = InventarioRepository(() async => db);
      movimentacaoRepo = MovimentacaoRepository(() async => db);
      produtoRepo = ProdutoRepository(AppDatabase.instance);
    });

    setUp(() async {
      await limparDados(db);
      usuarioId = await db.insert('usuarios', {
        'nome': 'Admin',
        'login': 'admin',
        'senha_hash': 'hash',
        'senha_salt': 'salt',
        'perfil': 'admin',
        'ativo': 1,
        'criado_em': DateTime.now().toIso8601String(),
      });
      categoriaId = (await db.query('categorias', limit: 1)).first['id'] as int;
      unidadeKgId =
          (await db.query(
                'unidades',
                where: 'sigla = ?',
                whereArgs: ['kg'],
              )).first['id']
              as int;
      unidadeUnId =
          (await db.query(
                'unidades',
                where: 'sigla = ?',
                whereArgs: ['un'],
              )).first['id']
              as int;
    });

    Future<int> criarProduto(
      String nome, {
      int? unidadeId,
      int saldo = 0,
    }) async {
      final id = await produtoRepo.criar(
        nome: nome,
        categoriaId: categoriaId,
        unidadeId: unidadeId ?? unidadeKgId,
        usuarioId: usuarioId,
      );
      if (saldo != 0) {
        await db.update(
          'produtos',
          {'saldo': saldo},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      return id;
    }

    Future<int> iniciar() => inventarioRepo.iniciar(usuarioId: usuarioId);

    Future<void> deveLancarAppException(Future<void> Function() acao) async {
      await expectLater(acao(), throwsA(isA<AppException>()));
    }

    test('inicia inventário e impede um segundo em andamento', () async {
      final id = await iniciar();
      expect((await inventarioRepo.porId(id))!.emAndamento, isTrue);
      await deveLancarAppException(iniciar);
      expect(
        await db.rawQuery(
          "SELECT id FROM inventarios WHERE status = 'em_andamento'",
        ),
        hasLength(1),
      );
    });

    test('valida, registra, atualiza e recusa contagens inválidas', () async {
      final inventarioId = await iniciar();
      final igual = await criarProduto('Igual', saldo: 2000);
      final divergente = await criarProduto('Divergente', saldo: 2000);
      final inativo = await criarProduto('Inativo');
      final fracionavel = await criarProduto('Unidade', unidadeId: unidadeUnId);

      await inventarioRepo.registrarContagem(
        inventarioId: inventarioId,
        produtoId: igual,
        qtdContada: 2000,
      );
      await deveLancarAppException(
        () => inventarioRepo.registrarContagem(
          inventarioId: inventarioId,
          produtoId: divergente,
          qtdContada: 1000,
        ),
      );
      expect(
        await db.query(
          'itens_inventario',
          where: 'produto_id = ?',
          whereArgs: [divergente],
        ),
        isEmpty,
      );

      await inventarioRepo.registrarContagem(
        inventarioId: inventarioId,
        produtoId: divergente,
        qtdContada: 1000,
        justificativa: 'Primeira contagem',
      );
      await inventarioRepo.registrarContagem(
        inventarioId: inventarioId,
        produtoId: divergente,
        qtdContada: 1500,
        justificativa: 'Recontagem',
      );
      final recontado = await db.query(
        'itens_inventario',
        where: 'inventario_id = ? AND produto_id = ?',
        whereArgs: [inventarioId, divergente],
      );
      expect(recontado, hasLength(1));
      expect(recontado.single['qtd_contada'], 1500);
      expect(recontado.single['justificativa'], 'Recontagem');

      await produtoRepo.definirAtivo(inativo, false);
      await deveLancarAppException(
        () => inventarioRepo.registrarContagem(
          inventarioId: inventarioId,
          produtoId: inativo,
          qtdContada: 0,
        ),
      );
      await deveLancarAppException(
        () => inventarioRepo.registrarContagem(
          inventarioId: inventarioId,
          produtoId: fracionavel,
          qtdContada: 1500,
          justificativa: 'Não deveria aceitar fração',
        ),
      );
    });

    test('remove uma contagem existente', () async {
      final inventarioId = await iniciar();
      final produtoId = await criarProduto('Produto', saldo: 1000);
      await inventarioRepo.registrarContagem(
        inventarioId: inventarioId,
        produtoId: produtoId,
        qtdContada: 1000,
      );
      final item = (await db.query('itens_inventario')).single;
      await inventarioRepo.removerItem(item['id'] as int);
      expect(await db.query('itens_inventario'), isEmpty);
    });

    test('finaliza, ajusta saldos e registra movimentos vinculados', () async {
      final inventarioId = await iniciar();
      final igual = await criarProduto('Igual', saldo: 5000);
      final sobra = await criarProduto('Sobra', saldo: 5000);
      final falta = await criarProduto('Falta', saldo: 5000);
      await inventarioRepo.registrarContagem(
        inventarioId: inventarioId,
        produtoId: igual,
        qtdContada: 5000,
      );
      await inventarioRepo.registrarContagem(
        inventarioId: inventarioId,
        produtoId: sobra,
        qtdContada: 7000,
        justificativa: 'Encontrado estoque adicional',
      );
      await inventarioRepo.registrarContagem(
        inventarioId: inventarioId,
        produtoId: falta,
        qtdContada: 3000,
        justificativa: 'Quebra identificada',
      );

      final resultado = await inventarioRepo.finalizar(
        inventarioId: inventarioId,
        usuarioId: usuarioId,
      );
      expect(resultado.ajustados, 2);
      expect(resultado.semDivergencia, 1);
      expect(
        (await db.query(
          'produtos',
          where: 'id = ?',
          whereArgs: [igual],
        )).single['saldo'],
        5000,
      );
      expect(
        (await db.query(
          'produtos',
          where: 'id = ?',
          whereArgs: [sobra],
        )).single['saldo'],
        7000,
      );
      expect(
        (await db.query(
          'produtos',
          where: 'id = ?',
          whereArgs: [falta],
        )).single['saldo'],
        3000,
      );

      final movimentos = await db.query(
        'movimentacoes',
        where: 'inventario_id = ?',
        whereArgs: [inventarioId],
      );
      expect(movimentos, hasLength(2));
      expect(movimentos.every((m) => m['tipo'] == 'ajuste'), isTrue);
      expect(movimentos.every((m) => m['usuario_id'] == usuarioId), isTrue);
      expect(
        movimentos.map((m) => m['observacao']),
        containsAll(['Encontrado estoque adicional', 'Quebra identificada']),
      );
      expect(movimentos.map((m) => m['saldo_apos']), containsAll([7000, 3000]));
      expect(
        (await db.query('itens_inventario'))
            .where((item) => item['divergencia'] != 0)
            .every((item) => item['ajustado'] == 1),
        isTrue,
      );
      expect((await inventarioRepo.porId(inventarioId))!.emAndamento, isFalse);
    });

    test('falha de item inativo reverte finalização inteira', () async {
      final inventarioId = await iniciar();
      final valido = await criarProduto('Válido', saldo: 5000);
      final inativado = await criarProduto('Inativado', saldo: 5000);
      await inventarioRepo.registrarContagem(
        inventarioId: inventarioId,
        produtoId: valido,
        qtdContada: 4000,
        justificativa: 'Diferença válida',
      );
      await inventarioRepo.registrarContagem(
        inventarioId: inventarioId,
        produtoId: inativado,
        qtdContada: 4000,
        justificativa: 'Diferença do item inativado',
      );
      await db.update(
        'produtos',
        {'ativo': 0},
        where: 'id = ?',
        whereArgs: [inativado],
      );

      await expectLater(
        inventarioRepo.finalizar(
          inventarioId: inventarioId,
          usuarioId: usuarioId,
        ),
        throwsA(isA<AppException>()),
      );
      expect(
        (await db.query(
          'produtos',
          where: 'id = ?',
          whereArgs: [valido],
        )).single['saldo'],
        5000,
      );
      expect(
        (await db.query(
          'produtos',
          where: 'id = ?',
          whereArgs: [inativado],
        )).single['saldo'],
        5000,
      );
      expect(await db.query('movimentacoes'), isEmpty);
      expect((await inventarioRepo.porId(inventarioId))!.emAndamento, isTrue);
    });

    test('bloqueia alterações depois de finalizar', () async {
      final inventarioId = await iniciar();
      final produtoId = await criarProduto('Produto', saldo: 1000);
      await inventarioRepo.registrarContagem(
        inventarioId: inventarioId,
        produtoId: produtoId,
        qtdContada: 1000,
      );
      final itemId = (await db.query('itens_inventario')).single['id'] as int;
      await inventarioRepo.finalizar(
        inventarioId: inventarioId,
        usuarioId: usuarioId,
      );

      await deveLancarAppException(
        () => inventarioRepo.registrarContagem(
          inventarioId: inventarioId,
          produtoId: produtoId,
          qtdContada: 1000,
        ),
      );
      await deveLancarAppException(() => inventarioRepo.removerItem(itemId));
      await expectLater(
        inventarioRepo.finalizar(
          inventarioId: inventarioId,
          usuarioId: usuarioId,
        ),
        throwsA(isA<AppException>()),
      );
    });

    test(
      'calcula ajuste sobre saldo atual após movimentação posterior',
      () async {
        final inventarioId = await iniciar();
        final produtoId = await criarProduto('Estoque variável', saldo: 5000);
        await inventarioRepo.registrarContagem(
          inventarioId: inventarioId,
          produtoId: produtoId,
          qtdContada: 4000,
          justificativa: 'Contagem',
        );
        await movimentacaoRepo.registrar(
          produtoId: produtoId,
          tipo: TipoMovimentacao.entrada,
          valor: 1000,
          usuarioId: usuarioId,
        );

        await inventarioRepo.finalizar(
          inventarioId: inventarioId,
          usuarioId: usuarioId,
        );
        final produto = (await db.query(
          'produtos',
          where: 'id = ?',
          whereArgs: [produtoId],
        )).single;
        final movimento = (await db.query(
          'movimentacoes',
          where: 'inventario_id = ?',
          whereArgs: [inventarioId],
        )).single;
        expect(produto['saldo'], 4000);
        expect(movimento['saldo_apos'], 4000);
        expect(movimento['delta'], -2000);
      },
    );

    test(
      'pede justificativa se saldo mudar após contagem sem divergência',
      () async {
        final inventarioId = await iniciar();
        final produtoId = await criarProduto(
          'Estoque sem justificativa',
          saldo: 5000,
        );
        await inventarioRepo.registrarContagem(
          inventarioId: inventarioId,
          produtoId: produtoId,
          qtdContada: 5000,
        );
        await movimentacaoRepo.registrar(
          produtoId: produtoId,
          tipo: TipoMovimentacao.entrada,
          valor: 1000,
          usuarioId: usuarioId,
        );

        await expectLater(
          inventarioRepo.finalizar(
            inventarioId: inventarioId,
            usuarioId: usuarioId,
          ),
          throwsA(
            isA<AppException>().having(
              (e) => e.message,
              'message',
              contains('justificativa'),
            ),
          ),
        );

        final produto = (await db.query(
          'produtos',
          where: 'id = ?',
          whereArgs: [produtoId],
        )).single;
        final item = (await db.query(
          'itens_inventario',
          where: 'inventario_id = ?',
          whereArgs: [inventarioId],
        )).single;
        final movimentos = await db.query('movimentacoes');
        expect(produto['saldo'], 6000);
        expect(item['ajustado'], 0);
        expect(movimentos, hasLength(1));
        expect(movimentos.single['inventario_id'], isNull);
        expect((await inventarioRepo.porId(inventarioId))!.emAndamento, isTrue);
      },
    );

    test(
      'consulta auditoria de ajustes positivos, negativos e sem ajuste',
      () async {
        final inventarioId = await iniciar();
        final sobra = await criarProduto('Produto com sobra', saldo: 3000);
        final falta = await criarProduto('Produto com falta', saldo: 7000);
        final igual = await criarProduto('Produto sem ajuste', saldo: 2500);
        await inventarioRepo.registrarContagem(
          inventarioId: inventarioId,
          produtoId: sobra,
          qtdContada: 5000,
          justificativa: 'Sobra na prateleira',
        );
        await inventarioRepo.registrarContagem(
          inventarioId: inventarioId,
          produtoId: falta,
          qtdContada: 5000,
          justificativa: 'Falta na contagem',
        );
        await inventarioRepo.registrarContagem(
          inventarioId: inventarioId,
          produtoId: igual,
          qtdContada: 2500,
        );

        final dataAjuste = DateTime(2026, 11, 2, 10, 30);
        await db.insert('movimentacoes', {
          'produto_id': sobra,
          'tipo': 'ajuste',
          'delta': 2000,
          'saldo_apos': 5000,
          'data_hora': dataAjuste.toIso8601String(),
          'usuario_id': usuarioId,
          'observacao': 'Sobra na prateleira',
          'inventario_id': inventarioId,
        });
        await db.insert('movimentacoes', {
          'produto_id': falta,
          'tipo': 'ajuste',
          'delta': -2000,
          'saldo_apos': 5000,
          'data_hora': dataAjuste
              .add(const Duration(minutes: 5))
              .toIso8601String(),
          'usuario_id': usuarioId,
          'observacao': 'Falta na contagem',
          'inventario_id': inventarioId,
        });

        final auditoria = await inventarioRepo.auditoria(inventarioId);
        expect(auditoria, hasLength(3));

        final linhaSobra = auditoria.singleWhere(
          (item) => item.produtoId == sobra,
        );
        expect(linhaSobra.produtoNome, 'Produto com sobra');
        expect(linhaSobra.qtdSistema, 3000);
        expect(linhaSobra.qtdContada, 5000);
        expect(linhaSobra.divergencia, 2000);
        expect(linhaSobra.saldoAntesAjuste, 3000);
        expect(linhaSobra.delta, 2000);
        expect(linhaSobra.saldoApos, 5000);
        expect(linhaSobra.justificativaAjuste, 'Sobra na prateleira');
        expect(linhaSobra.dataHoraAjuste, dataAjuste);
        expect(linhaSobra.usuarioAjusteId, usuarioId);
        expect(linhaSobra.usuarioAjusteNome, 'Admin');

        final linhaFalta = auditoria.singleWhere(
          (item) => item.produtoId == falta,
        );
        expect(linhaFalta.divergencia, -2000);
        expect(linhaFalta.saldoAntesAjuste, 7000);
        expect(linhaFalta.delta, -2000);
        expect(linhaFalta.saldoApos, 5000);
        expect(linhaFalta.temAjusteVinculado, isTrue);

        final linhaIgual = auditoria.singleWhere(
          (item) => item.produtoId == igual,
        );
        expect(linhaIgual.divergencia, 0);
        expect(linhaIgual.temAjusteVinculado, isFalse);
        expect(linhaIgual.delta, isNull);
        expect(linhaIgual.saldoAntesAjuste, isNull);
      },
    );

    test(
      'inventário antigo sem movimentos vinculados não causa erro',
      () async {
        final inventarioId = await iniciar();
        final produtoId = await criarProduto('Produto legado', saldo: 5000);
        await inventarioRepo.registrarContagem(
          inventarioId: inventarioId,
          produtoId: produtoId,
          qtdContada: 4000,
          justificativa: 'Diferença histórica',
        );
        await db.update(
          'inventarios',
          {'status': 'finalizado'},
          where: 'id = ?',
          whereArgs: [inventarioId],
        );

        final auditoria = await inventarioRepo.auditoria(inventarioId);

        expect(auditoria, hasLength(1));
        expect(auditoria.single.produtoNome, 'Produto legado');
        expect(auditoria.single.qtdSistema, 5000);
        expect(auditoria.single.qtdContada, 4000);
        expect(auditoria.single.divergencia, -1000);
        expect(auditoria.single.temAjusteVinculado, isFalse);
        expect(auditoria.single.dataHoraAjuste, isNull);
        expect(auditoria.single.usuarioAjusteNome, isNull);
      },
    );
  });
}
