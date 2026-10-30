import 'package:projeto_2/features/movimentacoes/models/movimentacao.dart';

class ConsultaSql {
  final String where;
  final List<Object?> args;
  const ConsultaSql(this.where, this.args);
}

class HistoricoFiltro {
  final int? produtoId;
  final DateTime? inicio; // dia inicial (inclusive); a hora é ignorada
  final DateTime? fim; // dia final (inclusive); a hora é ignorada
  final TipoMovimentacao? tipo;
  final int limite;

  const HistoricoFiltro({
    this.produtoId,
    this.inicio,
    this.fim,
    this.tipo,
    this.limite = 50,
  });

  bool get temFiltro =>
      produtoId != null || inicio != null || fim != null || tipo != null;

  HistoricoFiltro comLimite(int novoLimite) => HistoricoFiltro(
        produtoId: produtoId,
        inicio: inicio,
        fim: fim,
        tipo: tipo,
        limite: novoLimite,
      );

  ConsultaSql paraSql() {
    final condicoes = <String>[];
    final args = <Object?>[];
    final p = produtoId;
    final i = inicio;
    final f = fim;
    final t = tipo;

    if (p != null) {
      condicoes.add('m.produto_id = ?');
      args.add(p);
    }
    if (i != null) {
      condicoes.add('m.data_hora >= ?');
      args.add(DateTime(i.year, i.month, i.day).toIso8601String());
    }
    if (f != null) {
      condicoes.add('m.data_hora < ?');
      args.add(DateTime(f.year, f.month, f.day + 1).toIso8601String());
    }
    if (t != null) {
      condicoes.add('m.tipo = ?');
      args.add(t.valor);
    }

    final where =
        condicoes.isEmpty ? '' : 'WHERE ${condicoes.join(' AND ')}';
    return ConsultaSql(where, args);
  }
}