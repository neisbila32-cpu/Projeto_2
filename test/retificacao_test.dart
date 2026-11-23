import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:projeto_2/core/database/app_database.dart';
import 'package:projeto_2/core/utils/app_exception.dart';
import 'package:projeto_2/features/movimentacoes/models/movimentacao.dart';
import 'package:projeto_2/features/movimentacoes/repositories/movimentacao_repository.dart';

void main() {
  sqfliteFfiInit();
  late Directory dir;
  late Database db;
  late MovimentacaoRepository repo;
  late int autor, produto, entrada, saida;
  Future<Database> abrir(int versao) => databaseFactoryFfi.openDatabase(
    '${dir.path}/estoque.db',
    options: OpenDatabaseOptions(
      version: versao,
      onCreate: AppDatabase.criarEsquemaAtual,
      onUpgrade: AppDatabase.migrarEsquema,
      onConfigure: AppDatabase.prepararBancoParaMigracao,
      onOpen: AppDatabase.configurarBanco,
    ),
  );
  Future<int> usuario(String nome, String perfil) => db.insert('usuarios', {
    'nome': nome,
    'login': nome,
    'perfil': perfil,
    'ativo': 1,
    'criado_em': '2026-01-01',
    'senha_hash': 'x',
    'senha_salt': 'x',
  });
  Future<int> saldo() async =>
      (await db.query('produtos')).single['saldo'] as int;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('retificacao_');
    db = await abrir(4);
    autor = await usuario('autor', 'operador');
    produto = await db.insert('produtos', {
      'nome': 'Arroz',
      'categoria_id': (await db.query('categorias')).first['id'],
      'unidade_id': (await db.query(
        'unidades',
        where: 'fracionavel=0',
      )).first['id'],
      'saldo': 0,
      'ativo': 1,
      'criado_em': '2026-01-01',
      'criado_por': autor,
    });
    repo = MovimentacaoRepository(() async => db);
    await repo.registrar(
      produtoId: produto,
      tipo: TipoMovimentacao.entrada,
      valor: 10000,
      usuarioId: autor,
    );
    await repo.registrar(
      produtoId: produto,
      tipo: TipoMovimentacao.saida,
      valor: 3000,
      usuarioId: autor,
      finalidade: FinalidadeSaida.producao,
    );
    final linhas = await db.query('movimentacoes', orderBy: 'id');
    entrada = linhas.first['id'] as int;
    saida = linhas.last['id'] as int;
    await db.close();
    db = await abrir(AppDatabase.versaoAtual);
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });
  test(
    'retifica entrada e saída v4, preserva originais e auditoria ao reabrir',
    () async {
      final originais = await db.query('movimentacoes', orderBy: 'id');
      final admin = await usuario('gestor', 'admin');
      expect(await repo.retificaveisDoProduto(produto, admin), {
        entrada,
        saida,
      });
      await repo.retificar(
        id: entrada,
        usuarioId: autor,
        anterior: 10000,
        nova: 12000,
      );
      expect(await saldo(), 9000);
      await repo.retificar(
        id: saida,
        usuarioId: admin,
        anterior: 3000,
        nova: 2000,
      );
      await db.close();
      db = await abrir(AppDatabase.versaoAtual);
      expect(await saldo(), 10000);
      final linhas = await db.query('movimentacoes', orderBy: 'id');
      expect(linhas.take(2).toList(), originais);
      expect(linhas.last['usuario_id'], admin);
      expect(linhas.last['origem_id'], saida);
      expect(linhas.last['quantidade_anterior'], 3000);
      expect(linhas.last['quantidade_corrigida'], 2000);
      expect(DateTime.tryParse(linhas.last['data_hora'] as String), isNotNull);
      expect(await repo.quantidadeEfetiva(saida), 2000);
      await repo.retificar(
        id: saida,
        usuarioId: admin,
        anterior: 2000,
        nova: 4000,
      );
      expect(await saldo(), 8000);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );
  test(
    'rejeita saldo negativo, fração, valor obsoleto e operador de outro registro',
    () async {
      final outro = await usuario('outro', 'operador');
      expect(await repo.retificaveisDoProduto(produto, outro), isEmpty);
      for (final (id, antes, depois, ator) in [
        (saida, 3000, 12000, autor),
        (entrada, 10000, 2500, autor),
        (entrada, 9999, 8000, autor),
        (entrada, 10000, 8000, outro),
      ]) {
        await expectLater(
          repo.retificar(
            id: id,
            usuarioId: ator,
            anterior: antes,
            nova: depois,
          ),
          throwsA(isA<AppException>()),
        );
      }
      expect(await saldo(), 7000);
      expect(await db.query('movimentacoes'), hasLength(2));
    },
  );
  test(
    'bloqueia retificação de produto contado, inclusive sem divergência',
    () async {
      final inv = await db.insert('inventarios', {
        'status': 'em_andamento',
        'usuario_id': autor,
        'data_hora': DateTime.now().toIso8601String(),
      });
      await db.insert('itens_inventario', {
        'inventario_id': inv,
        'produto_id': produto,
        'qtd_sistema': 7000,
        'qtd_contada': 7000,
        'divergencia': 0,
      });
      expect(await repo.retificaveisDoProduto(produto, autor), isEmpty);
      for (final status in ['em_andamento', 'finalizado']) {
        await db.update('inventarios', {
          'status': status,
          'finalizado_em': DateTime.now().toIso8601String(),
        });
        await expectLater(
          repo.retificar(
            id: entrada,
            usuarioId: autor,
            anterior: 10000,
            nova: 12000,
          ),
          throwsA(isA<AppException>()),
        );
      }
      expect(await saldo(), 7000);
    },
  );
}
