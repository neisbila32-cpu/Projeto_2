import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:projeto_2/core/database/app_database.dart';
import 'package:projeto_2/features/historico/models/historico_filtro.dart';
import 'package:projeto_2/features/historico/repositories/historico_repository.dart';
import 'package:projeto_2/features/movimentacoes/models/movimentacao.dart';

final historicoRepositoryProvider = Provider<HistoricoRepository>((ref) {
  return HistoricoRepository(() => AppDatabase.instance.database);
});

class HistoricoFiltroNotifier extends Notifier<HistoricoFiltro> {
  @override
  HistoricoFiltro build() => const HistoricoFiltro();

  void limpar() {
    state = const HistoricoFiltro();
  }

  void setProduto(int? id) {
    state = HistoricoFiltro(
      produtoId: id,
      inicio: state.inicio,
      fim: state.fim,
      tipo: state.tipo,
    );
  }

  void setPeriodo(DateTime? inicio, DateTime? fim) {
    state = HistoricoFiltro(
      produtoId: state.produtoId,
      inicio: inicio,
      fim: fim,
      tipo: state.tipo,
    );
  }

  void setTipo(TipoMovimentacao? tipo) {
    state = HistoricoFiltro(
      produtoId: state.produtoId,
      inicio: state.inicio,
      fim: state.fim,
      tipo: tipo,
    );
  }

  void maisItens() {
    state = state.comLimite(state.limite + 50);
  }
}

final historicoFiltroProvider =
    NotifierProvider<HistoricoFiltroNotifier, HistoricoFiltro>(
  HistoricoFiltroNotifier.new,
);

final historicoProvider = FutureProvider.autoDispose<HistoricoPagina>((ref) {
  final filtro = ref.watch(historicoFiltroProvider);
  return ref.watch(historicoRepositoryProvider).consultar(filtro);
});