import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:projeto_2/core/database/app_database.dart';
import 'package:projeto_2/core/utils/app_exception.dart';
import 'package:projeto_2/features/backup/services/backup_service.dart';
import 'package:projeto_2/features/historico/models/historico_filtro.dart';
import 'package:projeto_2/features/historico/repositories/historico_repository.dart';
import 'package:projeto_2/features/inventario/repositories/inventario_repository.dart';
import 'package:projeto_2/features/movimentacoes/models/movimentacao.dart';
import 'package:projeto_2/features/movimentacoes/repositories/movimentacao_repository.dart';
import 'package:projeto_2/features/painel/models/painel_dados.dart';
import 'package:projeto_2/features/painel/repositories/painel_repository.dart';
import 'package:projeto_2/features/produtos/repositories/categoria_repository.dart';
import 'package:projeto_2/features/produtos/repositories/produto_repository.dart';
import 'package:projeto_2/features/relatorios/repositories/relatorio_repository.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  Database? banco;
  late int individualUsuarioId;
  late int individualProdutoId;
  late int compartilhadoProdutoId;
  late int compartilhadoCategoriaId;
  late int individualInventarioId;
  late int compartilhadoInventarioId;
  late int usuarioCompartilhadoId;
  late String individualContextoId;
  late String compartilhadoContextoId;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('contexto_isolamento_');
    final caminho = p.join(tempDir.path, 'estoque.db');
    final v2 = await databaseFactoryFfi.openDatabase(
      caminho,
      options: OpenDatabaseOptions(
        version: 2,
        onConfigure: AppDatabase.configurarBanco,
        onCreate: (db, version) => AppDatabase.criarEsquemaAtual(db, 2),
      ),
    );
    individualContextoId =
        (await v2.query('contexto_trabalho_atual')).single['contexto_id']
            as String;
    final agora = DateTime.now().toIso8601String();
    compartilhadoContextoId = '11111111-1111-4111-8111-111111111111';
    await v2.insert('contextos_trabalho', {
      'id': compartilhadoContextoId,
      'tipo': 'compartilhado',
      'nome': 'UAN de teste',
      'uan_remota_id': 'uan-remota-teste',
      'criado_em': agora,
      'ativo': 1,
    });

    final unidadeIndividualId =
        (await v2.query('unidades', limit: 1)).single['id'] as int;
    final unidadeCompartilhadaId = await v2.insert('unidades', {
      'sigla': 'u-sh',
      'nome': 'Unidade compartilhada',
      'fracionavel': 0,
      'ativa': 1,
      'contexto_id': compartilhadoContextoId,
    });
    final categoriaIndividualId =
        (await v2.query('categorias', limit: 1)).single['id'] as int;
    compartilhadoCategoriaId = await v2.insert('categorias', {
      'nome': 'Categoria compartilhada',
      'ativa': 1,
      'contexto_id': compartilhadoContextoId,
    });
    individualUsuarioId = await v2.insert('usuarios', {
      'nome': 'Usuário individual',
      'login': 'individual',
      'senha_hash': 'hash-individual',
      'senha_salt': 'salt-individual',
      'perfil': 'admin',
      'ativo': 1,
      'criado_em': agora,
      'contexto_id': individualContextoId,
    });
    usuarioCompartilhadoId = await v2.insert('usuarios', {
      'nome': 'Usuário compartilhado',
      'login': 'compartilhado',
      'senha_hash': 'hash-compartilhado',
      'senha_salt': 'salt-compartilhado',
      'perfil': 'operador',
      'ativo': 1,
      'criado_em': agora,
      'contexto_id': compartilhadoContextoId,
    });
    individualProdutoId = await v2.insert('produtos', {
      'nome': 'Produto individual',
      'categoria_id': categoriaIndividualId,
      'unidade_id': unidadeIndividualId,
      'saldo': 1234,
      'ativo': 1,
      'criado_em': agora,
      'criado_por': individualUsuarioId,
      'contexto_id': individualContextoId,
    });
    compartilhadoProdutoId = await v2.insert('produtos', {
      'nome': 'Produto compartilhado',
      'categoria_id': compartilhadoCategoriaId,
      'unidade_id': unidadeCompartilhadaId,
      'saldo': 8000,
      'ativo': 1,
      'criado_em': agora,
      'criado_por': usuarioCompartilhadoId,
      'contexto_id': compartilhadoContextoId,
    });
    individualInventarioId = await v2.insert('inventarios', {
      'data_hora': agora,
      'usuario_id': individualUsuarioId,
      'status': 'em_andamento',
      'contexto_id': individualContextoId,
    });
    compartilhadoInventarioId = await v2.insert('inventarios', {
      'data_hora': agora,
      'usuario_id': usuarioCompartilhadoId,
      'status': 'em_andamento',
      'contexto_id': compartilhadoContextoId,
    });
    await v2.insert('movimentacoes', {
      'produto_id': individualProdutoId,
      'tipo': 'entrada',
      'delta': 1234,
      'saldo_apos': 1234,
      'data_hora': agora,
      'usuario_id': individualUsuarioId,
      'contexto_id': individualContextoId,
    });
    await v2.insert('movimentacoes', {
      'produto_id': compartilhadoProdutoId,
      'tipo': 'entrada',
      'delta': 8000,
      'saldo_apos': 8000,
      'data_hora': agora,
      'usuario_id': usuarioCompartilhadoId,
      'contexto_id': compartilhadoContextoId,
    });
    await v2.insert('itens_inventario', {
      'inventario_id': individualInventarioId,
      'produto_id': individualProdutoId,
      'qtd_sistema': 1234,
      'qtd_contada': 1234,
      'divergencia': 0,
      'contexto_id': individualContextoId,
    });
    await v2.insert('itens_inventario', {
      'inventario_id': compartilhadoInventarioId,
      'produto_id': compartilhadoProdutoId,
      'qtd_sistema': 8000,
      'qtd_contada': 8000,
      'divergencia': 0,
      'contexto_id': compartilhadoContextoId,
    });
    await v2.close();

    banco = await databaseFactoryFfi.openDatabase(
      caminho,
      options: OpenDatabaseOptions(
        version: AppDatabase.versaoAtual,
        onConfigure: AppDatabase.configurarBanco,
        onCreate: AppDatabase.criarEsquemaAtual,
        onUpgrade: AppDatabase.migrarEsquema,
      ),
    );
    AppDatabase.injetarBancoParaTestes(banco!);
  });

  tearDown(() async {
    await banco?.close();
    await tempDir.delete(recursive: true);
  });

  test(
    'migração v2 preserva os dois contextos sem permitir alternância',
    () async {
      expect(await banco!.getVersion(), AppDatabase.versaoAtual);
      expect(
        (await banco!.query(
          'produtos',
          where: 'id = ?',
          whereArgs: [individualProdutoId],
        )).single['saldo'],
        1234,
      );
      expect(
        (await banco!.query(
          'produtos',
          where: 'id = ?',
          whereArgs: [compartilhadoProdutoId],
        )).single['saldo'],
        8000,
      );
      expect(await banco!.query('movimentacoes'), hasLength(2));
      expect(await banco!.query('inventarios'), hasLength(2));
      expect(await banco!.query('itens_inventario'), hasLength(2));
      expect(await banco!.query('usuarios'), hasLength(2));
      expect(await banco!.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      expect(
        (await banco!.rawQuery('PRAGMA integrity_check')).single.values.single,
        'ok',
      );

      await expectLater(
        banco!.update('contexto_trabalho_atual', {
          'contexto_id': compartilhadoContextoId,
        }, where: 'id = 1'),
        throwsA(anything),
      );
      final repositorio = ProdutoRepository(AppDatabase.instance);
      expect((await repositorio.listar()).single.nome, 'Produto individual');
    },
  );

  test(
    'consultas de catálogo, inventário, histórico, relatórios e painel isolam dados',
    () async {
      final produtos = await ProdutoRepository(AppDatabase.instance).listar();
      expect(produtos.map((produto) => produto.nome), ['Produto individual']);
      expect(
        await ProdutoRepository(
          AppDatabase.instance,
        ).buscarPorId(compartilhadoProdutoId),
        isNull,
      );
      expect(
        (await CategoriaRepository(AppDatabase.instance).listar(
          incluirInativas: true,
        )).any((categoria) => categoria.nome == 'Categoria compartilhada'),
        isFalse,
      );

      final inventarios = await InventarioRepository(
        () async => banco!,
      ).listar();
      expect(inventarios, hasLength(1));
      expect(inventarios.single.id, individualInventarioId);

      final historico = await HistoricoRepository(
        () async => banco!,
      ).consultar(const HistoricoFiltro());
      expect(historico.itens, hasLength(1));
      expect(historico.itens.single.produtoNome, 'Produto individual');

      final relatorios = RelatorioRepository(() async => banco!);
      expect(await relatorios.consultarEstoque(), hasLength(1));
      expect(
        await relatorios.consultarMovimentacoes(
          inicio: DateTime.now().subtract(const Duration(days: 1)),
          fim: DateTime.now().add(const Duration(days: 1)),
        ),
        hasLength(1),
      );

      final painel = await PainelRepository(() async => banco!).carregar(
        Intervalo(
          DateTime.now().subtract(const Duration(days: 1)),
          DateTime.now(),
        ),
      );
      expect(painel.resumo.entradas, 1);
    },
  );

  test(
    'repositórios mantêm saldo e negam acesso a produto de outro contexto',
    () async {
      final repositorio = MovimentacaoRepository(() async => banco!);
      await expectLater(
        repositorio.registrar(
          produtoId: compartilhadoProdutoId,
          tipo: TipoMovimentacao.entrada,
          valor: 1000,
          usuarioId: individualUsuarioId,
        ),
        throwsA(isA<AppException>()),
      );
      expect(
        await repositorio.ultimasDoProduto(compartilhadoProdutoId),
        isEmpty,
      );
      await repositorio.registrar(
        produtoId: individualProdutoId,
        tipo: TipoMovimentacao.entrada,
        valor: 1000,
        usuarioId: individualUsuarioId,
      );
      expect(
        (await banco!.query(
          'produtos',
          where: 'id = ?',
          whereArgs: [individualProdutoId],
        )).single['saldo'],
        2234,
      );
      expect(
        (await banco!.query(
          'produtos',
          where: 'id = ?',
          whereArgs: [compartilhadoProdutoId],
        )).single['saldo'],
        8000,
      );
    },
  );

  test(
    'gatilhos rejeitam referências entre contextos e troca do contexto',
    () async {
      final unidadeIndividualId =
          (await banco!.query(
                'unidades',
                where: 'contexto_id = ?',
                whereArgs: [individualContextoId],
                limit: 1,
              )).single['id']
              as int;
      await expectLater(
        banco!.insert('produtos', {
          'nome': 'Produto com categoria cruzada',
          'categoria_id': compartilhadoCategoriaId,
          'unidade_id': unidadeIndividualId,
          'saldo': 0,
          'ativo': 1,
          'criado_em': DateTime.now().toIso8601String(),
          'criado_por': individualUsuarioId,
          'contexto_id': individualContextoId,
        }),
        throwsA(anything),
      );
      await expectLater(
        banco!.insert('movimentacoes', {
          'produto_id': compartilhadoProdutoId,
          'tipo': 'entrada',
          'delta': 1,
          'saldo_apos': 8001,
          'data_hora': DateTime.now().toIso8601String(),
          'usuario_id': individualUsuarioId,
          'contexto_id': individualContextoId,
        }),
        throwsA(anything),
      );
      await expectLater(
        banco!.insert('inventarios', {
          'data_hora': DateTime.now().toIso8601String(),
          'usuario_id': usuarioCompartilhadoId,
          'status': 'em_andamento',
          'contexto_id': individualContextoId,
        }),
        throwsA(anything),
      );
      await expectLater(
        banco!.insert('itens_inventario', {
          'inventario_id': individualInventarioId,
          'produto_id': compartilhadoProdutoId,
          'qtd_sistema': 8000,
          'qtd_contada': 8000,
          'divergencia': 0,
          'contexto_id': individualContextoId,
        }),
        throwsA(anything),
      );
      expect(await banco!.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );

  test(
    'backup individual é recusado se houver dados de outro contexto',
    () async {
      final service = BackupService(
        obterBanco: () async => banco!,
        fecharBanco: () async {},
        caminhoBanco: () async => banco!.path,
      );
      await expectLater(service.exportar(), throwsA(isA<AppException>()));
      await banco!.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      final arquivoComOutroContexto = File(
        p.join(tempDir.path, 'backup_com_outro_contexto.db'),
      );
      await File(banco!.path).copy(arquivoComOutroContexto.path);
      await expectLater(
        service.validarArquivo(arquivoComOutroContexto),
        throwsA(isA<AppException>()),
      );
      await arquivoComOutroContexto.delete();
    },
  );
}
