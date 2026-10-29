enum TipoMovimentacao {
  entrada('entrada', 'Entrada'),
  saida('saida', 'Saída'),
  perda('perda', 'Perda'),
  ajuste('ajuste', 'Ajuste');

  final String valor;
  final String rotulo;
  const TipoMovimentacao(this.valor, this.rotulo);

  static TipoMovimentacao deValor(String valor) =>
      TipoMovimentacao.values.firstWhere((t) => t.valor == valor);
}

enum FinalidadeSaida {
  producao('producao', 'Produção'),
  transferencia('transferencia', 'Transferência'),
  outra('outra', 'Outra');

  final String valor;
  final String rotulo;
  const FinalidadeSaida(this.valor, this.rotulo);

  static FinalidadeSaida deValor(String valor) =>
      FinalidadeSaida.values.firstWhere((f) => f.valor == valor);
}

class Movimentacao {
  final int id;
  final int produtoId;
  final TipoMovimentacao tipo;
  final FinalidadeSaida? finalidade;
  final int delta; // em milésimos, com sinal
  final int saldoApos; // em milésimos
  final DateTime dataHora;
  final int usuarioId;
  final String? usuarioNome;
  final String? observacao;

  const Movimentacao({
    required this.id,
    required this.produtoId,
    required this.tipo,
    required this.finalidade,
    required this.delta,
    required this.saldoApos,
    required this.dataHora,
    required this.usuarioId,
    required this.usuarioNome,
    required this.observacao,
  });

  factory Movimentacao.fromMap(Map<String, Object?> m) {
    final fin = m['finalidade'] as String?;
    return Movimentacao(
      id: m['id'] as int,
      produtoId: m['produto_id'] as int,
      tipo: TipoMovimentacao.deValor(m['tipo'] as String),
      finalidade: fin == null ? null : FinalidadeSaida.deValor(fin),
      delta: m['delta'] as int,
      saldoApos: m['saldo_apos'] as int,
      dataHora: DateTime.parse(m['data_hora'] as String),
      usuarioId: m['usuario_id'] as int,
      usuarioNome: m['usuario_nome'] as String?,
      observacao: m['observacao'] as String?,
    );
  }
}