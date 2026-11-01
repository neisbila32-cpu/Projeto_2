import 'package:sqflite/sqflite.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:projeto_2/features/painel/models/painel_dados.dart';
import 'package:projeto_2/features/painel/repositories/painel_repository.dart';
import 'cenarios/apoio/banco_teste.dart';

void main() {
  late Database db;
  late PainelRepository repository;
  late int usuarioId;
  late int produtoAId; // categoria 'Gêneros secos' (1), unidade 'kg' (1, fracionável)
  late int produtoBId; // categoria 'Perecíveis' (2), unidade 'un' (5, não fracionável)

  Future<int> _inserirUsuario() async {
    return await db.insert('usuarios', {
      'nome': 'Usuário Teste',
      'login': 'usuario_teste',
      'senha_hash': 'hash',
      'senha_salt': 'salt',
      'perfil': 'operador',
      'ativo': 1,
      'criado_em': '2026-01-01T00:00:00',
    });
  }

  Future<int> _inserirProduto({
    required int unidadeId,
    required int categoriaId,
    required String nome,
  }) async {
    return await db.insert('produtos', {
      'nome': nome,
      'categoria_id': categoriaId,
      'unidade_id': unidadeId,
      'saldo': 0,
      'ativo': 1,
      'criado_em': '2026-01-01T00:00:00',
      'criado_por': usuarioId,
    });
  }

  Future<void> _inserirMov({
    required int produtoId,
    required String tipo,
    required int delta,
    required int saldoApos,
    required String dataHora,
  }) async {
    await db.insert('movimentacoes', {
      'produto_id': produtoId,
      'tipo': tipo,
      'delta': delta,
      'saldo_apos': saldoApos,
      'data_hora': dataHora,
      'usuario_id': usuarioId,
      'observacao': null,
    });
  }

  setUp(() async {
    db = await abrirBancoEmMemoria();
    usuarioId = await _inserirUsuario();
    produtoAId = await _inserirProduto(
      unidadeId: 1,
      categoriaId: 1,
      nome: 'Arroz',
    );
    produtoBId = await _inserirProduto(
      unidadeId: 5,
      categoriaId: 2,
      nome: 'Sabão',
    );
    await _inserirMov(
      produtoId: produtoAId,
      tipo: 'entrada',
      delta: 10000,
      saldoApos: 10000,
      dataHora: '2026-10-10T10:00:00',
    );
    await _inserirMov(
      produtoId: produtoAId,
      tipo: 'saida',
      delta: -2000,
      saldoApos: 8000,
      dataHora: '2026-10-15T10:00:00',
    );
    await _inserirMov(
      produtoId: produtoAId,
      tipo: 'saida',
      delta: -1000,
      saldoApos: 7000,
      dataHora: '2026-10-20T10:00:00',
    );
    await _inserirMov(
      produtoId: produtoAId,
      tipo: 'perda',
      delta: -500,
      saldoApos: 6500,
      dataHora: '2026-10-25T10:00:00',
    );
    await _inserirMov(
      produtoId: produtoBId,
      tipo: 'saida',
      delta: -3000,
      saldoApos: 1000,
      dataHora: '2026-10-28T10:00:00',
    );
    await _inserirMov(
      produtoId: produtoBId,
      tipo: 'ajuste',
      delta: 800,
      saldoApos: 1800,
      dataHora: '2026-10-29T10:00:00',
    );
    // Último dia do intervalo, às 23:59:59: deve entrar.
    await _inserirMov(
      produtoId: produtoAId,
      tipo: 'saida',
      delta: -4000,
      saldoApos: 2500,
      dataHora: '2026-10-31T23:59:59',
    );
    // Dia seguinte, às 00:00:00.000 (limite exclusivo): não deve entrar.
    await _inserirMov(
      produtoId: produtoAId,
      tipo: 'saida',
      delta: -1000,
      saldoApos: 1500,
      dataHora: '2026-11-01T00:00:00.000',
    );
    repository = PainelRepository(() async => db);
  });

  tearDown(() async {
    await limparDados(db);
    await db.close();
  });

  final intervalo = Intervalo(DateTime(2026, 10, 1), DateTime(2026, 10, 31));

  group('PainelDados.resumo', () {
    test('conta cada tipo de movimentação no período', () async {
      final dados = await repository.carregar(intervalo);
      expect(dados.resumo.entradas, 1);
      expect(dados.resumo.saidas, 4);
      expect(dados.resumo.perdas, 1);
      expect(dados.resumo.ajustes, 1);
      expect(dados.resumo.total, 7);
    });
  });

  group('PainelDados.porCategoria', () {
    test('só contabiliza saídas, ordena decrescente e respeita limite', () async {
      final dados = await repository.carregar(intervalo, limiteRanking: 2);
      expect(dados.porCategoria.length, 2);
      expect(dados.porCategoria[0].nome, 'Gêneros secos');
      expect(dados.porCategoria[0].saidas, 3);
      expect(dados.porCategoria[1].nome, 'Perecíveis');
      expect(dados.porCategoria[1].saidas, 1);
    });

    test('respeita limite de 1', () async {
      final dados = await repository.carregar(intervalo, limiteRanking: 1);
      expect(dados.porCategoria.length, 1);
      expect(dados.porCategoria.single.nome, 'Gêneros secos');
    });
  });

  group('PainelDados.porProduto', () {
    test('quantidade positiva somada, sigla e fracionável da unidade', () async {
      final dados = await repository.carregar(intervalo);

      final arroz = dados.porProduto.firstWhere((p) => p.nome == 'Arroz');
      expect(arroz.saidas, 3);
      expect(arroz.quantidade, 7000);
      expect(arroz.unidadeSigla, 'kg');
      expect(arroz.fracionavel, isTrue);

      final sabao = dados.porProduto.firstWhere((p) => p.nome == 'Sabão');
      expect(sabao.saidas, 1);
      expect(sabao.quantidade, 3000);
      expect(sabao.unidadeSigla, 'un');
      expect(sabao.fracionavel, isFalse);
    });

    test('ordenado por saidas desc e depois quantidade desc', () async {
      final dados = await repository.carregar(intervalo);
      expect(dados.porProduto[0].nome, 'Arroz');
      expect(dados.porProduto[1].nome, 'Sabão');
    });
  });

  group('fronteira do intervalo', () {
    test('movimento às 23:59:59 do último dia entra; 00:00:00 do dia seguinte não', () async {
      final dados = await repository.carregar(intervalo);
      // A saída de 2026-10-31T23:59:59 conta; a de 2026-11-01T00:00:00.000 não.
      expect(dados.resumo.saidas, 4);
    });
  });

  group('PainelDados.porDia', () {
    test('tem um item por dia do intervalo, com zeros nos dias sem movimento', () async {
      final dados = await repository.carregar(intervalo);
      expect(dados.porDia.length, 31);
      expect(dados.porDia.first.dia, DateTime(2026, 10, 1));
      expect(dados.porDia.first.total, 0);
      expect(dados.porDia.last.dia, DateTime(2026, 10, 31));
      expect(dados.porDia.last.total, 1);
      expect(
        dados.porDia.where((d) => d.total > 0).map((d) => d.dia).toList(),
        [
          DateTime(2026, 10, 10),
          DateTime(2026, 10, 15),
          DateTime(2026, 10, 20),
          DateTime(2026, 10, 25),
          DateTime(2026, 10, 28),
          DateTime(2026, 10, 29),
          DateTime(2026, 10, 31),
        ],
      );
    });
  });
}