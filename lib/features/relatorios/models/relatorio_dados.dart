class LinhaEstoqueRelatorio {
  const LinhaEstoqueRelatorio({
    required this.produtoId,
    required this.produtoNome,
    required this.categoriaNome,
    required this.unidadeSigla,
    required this.fracionavel,
    required this.saldo,
    required this.ativo,
  });

  final int produtoId;
  final String produtoNome;
  final String categoriaNome;
  final String unidadeSigla;
  final bool fracionavel;
  final int saldo;
  final bool ativo;
}

class LinhaMovimentacaoRelatorio {
  const LinhaMovimentacaoRelatorio({
    required this.id,
    required this.dataHora,
    required this.produtoNome,
    required this.unidadeSigla,
    required this.fracionavel,
    required this.tipo,
    required this.delta,
    required this.saldoApos,
    required this.usuarioNome,
    required this.observacao,
  });

  final int id;
  final DateTime dataHora;
  final String produtoNome;
  final String unidadeSigla;
  final bool fracionavel;
  final String tipo;
  final int delta;
  final int saldoApos;
  final String usuarioNome;
  final String? observacao;
}
