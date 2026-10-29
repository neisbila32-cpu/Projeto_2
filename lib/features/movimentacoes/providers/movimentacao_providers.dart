import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:projeto_2/core/database/app_database.dart';
import 'package:projeto_2/features/movimentacoes/models/movimentacao.dart';
import 'package:projeto_2/features/movimentacoes/repositories/movimentacao_repository.dart';

final movimentacaoRepositoryProvider = Provider<MovimentacaoRepository>((ref) {
  return MovimentacaoRepository(() => AppDatabase.instance.database);
});

final ultimasMovimentacoesProvider =
    FutureProvider.family<List<Movimentacao>, int>((ref, produtoId) {
  return ref
      .watch(movimentacaoRepositoryProvider)
      .ultimasDoProduto(produtoId);
});