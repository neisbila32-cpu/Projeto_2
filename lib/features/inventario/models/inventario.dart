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

class AuditoriaItemInventario {
  const AuditoriaItemInventario({
    required this.itemId,
    required this.inventarioId,
    required this.produtoId,
    required this.produtoNome,
    required this.unidadeSigla,
    required this.fracionavel,
    required this.qtdSistema,
    required this.qtdContada,
    required this.divergencia,
    required this.justificativaContagem,
    required this.ajusteId,
    required this.delta,
    required this.saldoApos,
    required this.dataHoraAjuste,
    required this.usuarioAjusteId,
    required this.usuarioAjusteNome,
    required this.justificativaAjuste,
  });

  final int itemId;
  final int inventarioId;
  final int produtoId;
  final String produtoNome;
  final String unidadeSigla;
  final bool fracionavel;
  final int qtdSistema;
  final int qtdContada;
  final int divergencia;
  final String? justificativaContagem;
  final int? ajusteId;
  final int? delta;
  final int? saldoApos;
  final DateTime? dataHoraAjuste;
  final int? usuarioAjusteId;
  final String? usuarioAjusteNome;
  final String? justificativaAjuste;

  bool get temAjusteVinculado => ajusteId != null;

  int? get saldoAntesAjuste {
    final deltaAjuste = delta;
    final saldoFinal = saldoApos;
    if (deltaAjuste == null || saldoFinal == null) return null;
    return saldoFinal - deltaAjuste;
  }

  factory AuditoriaItemInventario.fromMap(Map<String, Object?> m) =>
      AuditoriaItemInventario(
        itemId: m['item_id'] as int,
        inventarioId: m['inventario_id'] as int,
        produtoId: m['produto_id'] as int,
        produtoNome: m['produto_nome'] as String,
        unidadeSigla: m['unidade_sigla'] as String,
        fracionavel: (m['fracionavel'] as int) == 1,
        qtdSistema: m['qtd_sistema'] as int,
        qtdContada: m['qtd_contada'] as int,
        divergencia: m['divergencia'] as int,
        justificativaContagem: m['justificativa_contagem'] as String?,
        ajusteId: m['ajuste_id'] as int?,
        delta: m['delta'] as int?,
        saldoApos: m['saldo_apos'] as int?,
        dataHoraAjuste: m['ajuste_data_hora'] == null
            ? null
            : DateTime.parse(m['ajuste_data_hora'] as String),
        usuarioAjusteId: m['ajuste_usuario_id'] as int?,
        usuarioAjusteNome: m['ajuste_usuario_nome'] as String?,
        justificativaAjuste: m['justificativa_ajuste'] as String?,
      );
}
