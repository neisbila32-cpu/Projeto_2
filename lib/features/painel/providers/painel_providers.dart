import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:projeto_2/core/database/app_database.dart';
import 'package:projeto_2/features/painel/models/painel_dados.dart';
import 'package:projeto_2/features/painel/repositories/painel_repository.dart';

/// Repositório de leitura do painel (consultas de gráficos).
final painelRepositoryProvider = Provider<PainelRepository>((ref) {
  return PainelRepository(() => AppDatabase.instance.database);
});

/// Atalho de período selecionado no painel.
class PainelAtalhoNotifier extends Notifier<PainelAtalho> {
  @override
  PainelAtalho build() => PainelAtalho.seteDias;

  /// Define o atalho de período ativo.
  void definir(PainelAtalho atalho) {
    state = atalho;
  }
}

final painelAtalhoProvider =
    NotifierProvider<PainelAtalhoNotifier, PainelAtalho>(PainelAtalhoNotifier.new);

/// Dados do painel para o atalho de período selecionado.
final painelProvider = FutureProvider.autoDispose<PainelDados>((ref) {
  final atalho = ref.watch(painelAtalhoProvider);
  final intervalo = atalho.intervalo(DateTime.now());
  return ref.watch(painelRepositoryProvider).carregar(intervalo);
});