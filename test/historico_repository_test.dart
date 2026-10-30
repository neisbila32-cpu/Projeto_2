import 'package:sqflite/sqflite.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:projeto_2/features/historico/models/historico_filtro.dart';
import 'package:projeto_2/features/historico/repositories/historico_repository.dart';
import 'package:projeto_2/features/movimentacoes/models/movimentacao.dart';
import 'cenarios/apoio/banco_teste.dart';

void main() {
  late Database db;
  late HistoricoRepository repository;
  late int usuarioId;
  late int produtoAId;
  late int produtoBId;

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

  Future<int> _inserirProduto({required int unidadeId, required String nome}) async {
    return await db.insert('produtos', {
      'nome': nome,
      'categoria_id': 1,
      'unidade_id': unidadeId,
      'saldo': 0,
      'ativo': 1,
      'criado_em': '2026-01-01T00:00:00',
      'criado_por': 1,
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
    produtoAId = await _inserirProduto(unidadeId: 1, nome: 'Produto A');
    produtoBId = await _inserirProduto(unidadeId: 5, nome: 'Produto B');
    await _inserirMov(produtoId: produtoAId, tipo: 'entrada', delta: 10000, saldoApos: 10000, dataHora: '2026-10-01T10:00:00');
    await _inserirMov(produtoId: produtoAId, tipo: 'saida', delta: -3000, saldoApos: 7000, dataHora: '2026-10-15T10:00:00');
    await _inserirMov(produtoId: produtoAId, tipo: 'saida', delta: -1000, saldoApos: 6000, dataHora: '2026-10-31T23:59:59');
    await _inserirMov(produtoId: produtoBId, tipo: 'entrada', delta: 5000, saldoApos: 5000, dataHora: '2026-10-20T10:00:00');
    repository = HistoricoRepository(() async => db);
  });

  tearDown(() async {
    await limparDados(db);
    await db.close();
  });

  group('HistoricoRepository.consultar', () {
    test('filtro por produto retorna apenas desse produto', () async {
      final pagina = await repository.consultar(const HistoricoFiltro(produtoId: 1));
      expect(pagina.itens.length, 3);
      expect(pagina.itens.every((i) => i.movimentacao.produtoId == 1), isTrue);
      expect(pagina.temMais, isFalse);
    });

    test('filtro por período: início e fim inclusivos', () async {
      final pagina = await repository.consultar(HistoricoFiltro(
        inicio: DateTime(2026, 10, 1),
        fim: DateTime(2026, 10, 31),
      ));
      expect(pagina.itens.length, 4);
      expect(
        pagina.itens.any((i) => i.movimentacao.dataHora == DateTime(2026, 10, 31, 23, 59, 59)),
        isTrue,
      );
    });

    test('filtro por tipo', () async {
      final pagina = await repository.consultar(const HistoricoFiltro(tipo: TipoMovimentacao.saida));
      expect(pagina.itens.length, 2);
      expect(pagina.itens.every((i) => i.movimentacao.tipo == TipoMovimentacao.saida), isTrue);
    });

    test('filtros combinados: produto + tipo + período', () async {
      final pagina = await repository.consultar(HistoricoFiltro(
        produtoId: 1,
        tipo: TipoMovimentacao.saida,
        inicio: DateTime(2026, 10, 1),
        fim: DateTime(2026, 10, 31),
      ));
      expect(pagina.itens.length, 2);
      expect(
        pagina.itens.every(
          (i) => i.movimentacao.produtoId == 1 && i.movimentacao.tipo == TipoMovimentacao.saida,
        ),
        isTrue,
      );
    });

    test('ordem decrescente por data_hora', () async {
      final pagina = await repository.consultar(const HistoricoFiltro(limite: 50));
      expect(pagina.itens.length, 4);
      for (var i = 0; i < pagina.itens.length - 1; i++) {
        final atual = pagina.itens[i].movimentacao.dataHora;
        final proximo = pagina.itens[i + 1].movimentacao.dataHora;
        expect(atual.isAfter(proximo) || atual.isAtSameMomentAs(proximo), isTrue,
            reason: '$atual deve ser >= que $proximo');
      }
    });
  });
}