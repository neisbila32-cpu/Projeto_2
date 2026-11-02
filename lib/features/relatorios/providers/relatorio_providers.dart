import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:projeto_2/core/database/app_database.dart';
import 'package:projeto_2/features/relatorios/models/relatorio_dados.dart';
import 'package:projeto_2/features/relatorios/repositories/relatorio_repository.dart';

final relatorioRepositoryProvider = Provider<RelatorioRepository>((ref) {
  return RelatorioRepository(() => AppDatabase.instance.database);
});

final estoqueRelatorioProvider =
    FutureProvider.autoDispose<List<LinhaEstoqueRelatorio>>((ref) {
  return ref.watch(relatorioRepositoryProvider).consultarEstoque();
});

final movimentacoesRelatorioProvider = FutureProvider.autoDispose
    .family<List<LinhaMovimentacaoRelatorio>, ({DateTime inicio, DateTime fim})>(
        (ref, periodo) {
  return ref.watch(relatorioRepositoryProvider).consultarMovimentacoes(
        inicio: periodo.inicio,
        fim: periodo.fim,
      );
});
