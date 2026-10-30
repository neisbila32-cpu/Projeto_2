import 'package:projeto_2/features/historico/models/historico_filtro.dart';
import 'package:projeto_2/features/movimentacoes/models/movimentacao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HistoricoFiltro.paraSql', () {
    test('sem filtros: where vazio e args vazio', () {
      final filtro = HistoricoFiltro();
      final sql = filtro.paraSql();
      expect(sql.where, '');
      expect(sql.args, isEmpty);
    });

    test('só produto 5: where contém m.produto_id = ? e args == [5]', () {
      final filtro = HistoricoFiltro(produtoId: 5);
      final sql = filtro.paraSql();
      expect(sql.where, contains('m.produto_id = ?'));
      expect(sql.args, [5]);
    });

    test('início em 2026-10-01 15:30 ignora a hora', () {
      final filtro = HistoricoFiltro(
        inicio: DateTime(2026, 10, 1, 15, 30),
      );
      final sql = filtro.paraSql();
      expect(sql.where, contains('m.data_hora >= ?'));
      expect(sql.args, [DateTime(2026, 10, 1).toIso8601String()]);
    });

    test('fim em 2026-10-31 gera args com 2026-11-01', () {
      final filtro = HistoricoFiltro(fim: DateTime(2026, 10, 31));
      final sql = filtro.paraSql();
      expect(sql.where, contains('m.data_hora < ?'));
      expect(sql.args, [DateTime(2026, 11, 1).toIso8601String()]);
    });

    test('fim em 2026-12-31 gera args com 2027-01-01', () {
      final filtro = HistoricoFiltro(fim: DateTime(2026, 12, 31));
      final sql = filtro.paraSql();
      expect(sql.where, contains('m.data_hora < ?'));
      expect(sql.args, [DateTime(2027, 1, 1).toIso8601String()]);
    });

    test('todos os filtros juntos: WHERE com 4 condições e args em ordem', () {
      final filtro = HistoricoFiltro(
        produtoId: 3,
        inicio: DateTime(2026, 10, 1),
        fim: DateTime(2026, 10, 31),
        tipo: TipoMovimentacao.saida,
      );
      final sql = filtro.paraSql();
      expect(sql.where, startsWith('WHERE '));
      expect(sql.where.split(' AND '), hasLength(4));
      expect(sql.args, [
        3,
        DateTime(2026, 10, 1).toIso8601String(),
        DateTime(2026, 11, 1).toIso8601String(),
        'saida',
      ]);
    });
  });

  group('HistoricoFiltro.temFiltro', () {
    test('é false sem filtros', () {
      expect(HistoricoFiltro().temFiltro, isFalse);
    });

    test('é true com produtoId', () {
      expect(HistoricoFiltro(produtoId: 1).temFiltro, isTrue);
    });

    test('é true com início', () {
      expect(HistoricoFiltro(inicio: DateTime(2026, 1, 1)).temFiltro, isTrue);
    });

    test('é true com fim', () {
      expect(HistoricoFiltro(fim: DateTime(2026, 1, 1)).temFiltro, isTrue);
    });

    test('é true com tipo', () {
      expect(HistoricoFiltro(tipo: TipoMovimentacao.entrada).temFiltro,
          isTrue);
    });
  });

  group('HistoricoFiltro.comLimite', () {
    test('mantém os filtros e troca só o limite', () {
      final original = HistoricoFiltro(
        produtoId: 7,
        inicio: DateTime(2026, 10, 1),
        fim: DateTime(2026, 10, 31),
        tipo: TipoMovimentacao.perda,
        limite: 25,
      );
      final modificado = original.comLimite(100);
      expect(modificado.produtoId, 7);
      expect(modificado.inicio, DateTime(2026, 10, 1));
      expect(modificado.fim, DateTime(2026, 10, 31));
      expect(modificado.tipo, TipoMovimentacao.perda);
      expect(modificado.limite, 100);
    });
  });
}