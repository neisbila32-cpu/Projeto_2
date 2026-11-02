class Inventario {
  final int id;
  final DateTime dataHora;
  final int usuarioId;
  final String? usuarioNome;
  final bool emAndamento;
  final String? observacao;
  final int totalItens;
  final int totalDivergentes;

  const Inventario({
    required this.id,
    required this.dataHora,
    required this.usuarioId,
    required this.usuarioNome,
    required this.emAndamento,
    required this.observacao,
    required this.totalItens,
    required this.totalDivergentes,
  });

  factory Inventario.fromMap(Map<String, Object?> m) => Inventario(
        id: m['id'] as int,
        dataHora: DateTime.parse(m['data_hora'] as String),
        usuarioId: m['usuario_id'] as int,
        usuarioNome: m['usuario_nome'] as String?,
        emAndamento: (m['status'] as String) == 'em_andamento',
        observacao: m['observacao'] as String?,
        totalItens: (m['total_itens'] as int?) ?? 0,
        totalDivergentes: (m['total_divergentes'] as int?) ?? 0,
      );
}

class ItemInventario {
  final int id;
  final int inventarioId;
  final int produtoId;
  final String produtoNome;
  final String unidadeSigla;
  final bool fracionavel;
  final int qtdSistema; // milésimos, saldo no momento da contagem
  final int qtdContada; // milésimos
  final int divergencia; // milésimos, contado menos sistema
  final String? justificativa;
  final bool ajustado;

  const ItemInventario({
    required this.id,
    required this.inventarioId,
    required this.produtoId,
    required this.produtoNome,
    required this.unidadeSigla,
    required this.fracionavel,
    required this.qtdSistema,
    required this.qtdContada,
    required this.divergencia,
    required this.justificativa,
    required this.ajustado,
  });

  factory ItemInventario.fromMap(Map<String, Object?> m) => ItemInventario(
        id: m['id'] as int,
        inventarioId: m['inventario_id'] as int,
        produtoId: m['produto_id'] as int,
        produtoNome: m['produto_nome'] as String,
        unidadeSigla: m['unidade_sigla'] as String,
        fracionavel: (m['fracionavel'] as int) == 1,
        qtdSistema: m['qtd_sistema'] as int,
        qtdContada: m['qtd_contada'] as int,
        divergencia: m['divergencia'] as int,
        justificativa: m['justificativa'] as String?,
        ajustado: (m['ajustado'] as int) == 1,
      );
}
