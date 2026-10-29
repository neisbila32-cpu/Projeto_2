import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Filtro da tela de histórico de movimentações.
class HistoricoFiltro {
  const HistoricoFiltro({this.produtoId});

  final int? produtoId;
}

class HistoricoFiltroNotifier extends Notifier<HistoricoFiltro> {
  @override
  HistoricoFiltro build() => const HistoricoFiltro();

  void limpar() {
    state = const HistoricoFiltro();
  }

  void setProduto(int produtoId) {
    state = HistoricoFiltro(produtoId: produtoId);
  }
}

final historicoFiltroProvider =
    NotifierProvider<HistoricoFiltroNotifier, HistoricoFiltro>(
  HistoricoFiltroNotifier.new,
);