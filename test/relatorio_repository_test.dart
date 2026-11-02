import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:projeto_2/core/database/app_database.dart';
import 'package:projeto_2/features/relatorios/repositories/relatorio_repository.dart';
import 'package:projeto_2/features/relatorios/services/relatorio_csv.dart';
import 'cenarios/apoio/banco_teste.dart';

void main() {
  late Database db;
  late RelatorioRepository repository;
  late int usuarioId;
  late int categoriaId;
  late int unidadeKgId;

  setUpAll(() async {
    await abrirBancoEmMemoria();
    db = await AppDatabase.instance.database;
    repository = RelatorioRepository(() async => db);
  });

  setUp(() async {
    await limparDados(db);
    usuarioId = await db.insert('usuarios', {
      'nome': 'Operador de teste',
      'login': 'operador',
      'senha_hash': 'hash',
      'senha_salt': 'salt',
      'perfil': 'operador',
      'ativo': 1,
      'criado_em': DateTime(2026).toIso8601String(),
    });
    categoriaId = (await db.query('categorias', limit: 1)).first['id'] as int;
    unidadeKgId = (await db.query('unidades',
        where: 'sigla = ?', whereArgs: ['kg'])).first['id'] as int;
  });

  Future<int> criarProduto(String nome, int saldo) => db.insert('produtos', {
        'nome': nome,
        'categoria_id': categoriaId,
        'unidade_id': unidadeKgId,
        'saldo': saldo,
        'ativo': 1,
        'criado_em': DateTime(2026).toIso8601String(),
        'criado_por': usuarioId,
      });

  test('consulta posição atual com produto, categoria, unidade e saldo', () async {
    await criarProduto('Arroz', 1500);

    final linhas = await repository.consultarEstoque();

    expect(linhas, hasLength(1));
    expect(linhas.single.produtoNome, 'Arroz');
    expect(linhas.single.unidadeSigla, 'kg');
    expect(linhas.single.fracionavel, isTrue);
    expect(linhas.single.saldo, 1500);
    expect(linhas.single.ativo, isTrue);
  });

  test('filtra movimentações pelo período, inclusive o último dia', () async {
    final produtoId = await criarProduto('Feijão', 2000);
    Future<void> inserirMovimentacao(DateTime data) async {
      await db.insert('movimentacoes', {
        'produto_id': produtoId,
        'tipo': 'entrada',
        'finalidade': null,
        'delta': 1000,
        'saldo_apos': 1000,
        'data_hora': data.toIso8601String(),
        'usuario_id': usuarioId,
        'observacao': 'Reposição',
      });
    }

    await inserirMovimentacao(DateTime(2026, 10, 31, 23, 59));
    await inserirMovimentacao(DateTime(2026, 11, 1, 0, 0));
    await inserirMovimentacao(DateTime(2026, 11, 2, 12));

    final linhas = await repository.consultarMovimentacoes(
      inicio: DateTime(2026, 11, 1),
      fim: DateTime(2026, 11, 1),
    );

    expect(linhas, hasLength(1));
    expect(linhas.single.dataHora, DateTime(2026, 11, 1));
    expect(linhas.single.produtoNome, 'Feijão');
    expect(linhas.single.usuarioNome, 'Operador de teste');
  });

  test('gera CSV UTF-8 com cabeçalho e campos escapados', () async {
    await criarProduto('Arroz; integral', 1500);
    final linhas = await repository.consultarEstoque();

    final csv = RelatorioCsv.estoque(linhas);

    expect(csv.startsWith('\uFEFFID;Produto;Categoria;Saldo;Status'), isTrue);
    expect(csv, contains('"Arroz; integral"'));
    expect(csv, contains('1,5 kg'));
    expect(csv, contains('Ativo'));
  });
}
