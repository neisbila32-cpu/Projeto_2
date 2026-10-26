import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:projeto_2/core/database/app_database.dart';
import 'package:projeto_2/features/produtos/models/categoria.dart';
import 'package:projeto_2/features/produtos/models/produto.dart';
import 'package:projeto_2/features/produtos/models/unidade.dart';
import 'package:projeto_2/features/produtos/repositories/categoria_repository.dart';
import 'package:projeto_2/features/produtos/repositories/produto_repository.dart';
import 'package:projeto_2/features/produtos/repositories/unidade_repository.dart';

final produtoRepositoryProvider = Provider<ProdutoRepository>((ref) {
  return ProdutoRepository(AppDatabase.instance);
});

final categoriaRepositoryProvider = Provider<CategoriaRepository>((ref) {
  return CategoriaRepository(AppDatabase.instance);
});

final unidadeRepositoryProvider = Provider<UnidadeRepository>((ref) {
  return UnidadeRepository(AppDatabase.instance);
});

/// Filtros da lista de produtos.
class ProdutoFiltro {
  const ProdutoFiltro({
    this.busca = '',
    this.categoriaId,
    this.incluirInativos = false,
  });

  final String busca;
  final int? categoriaId;
  final bool incluirInativos;
}

class ProdutoFiltroNotifier extends Notifier<ProdutoFiltro> {
  @override
  ProdutoFiltro build() => const ProdutoFiltro();

  void setBusca(String busca) {
    state = ProdutoFiltro(
      busca: busca,
      categoriaId: state.categoriaId,
      incluirInativos: state.incluirInativos,
    );
  }

  /// null = todas as categorias.
  void setCategoria(int? categoriaId) {
    state = ProdutoFiltro(
      busca: state.busca,
      categoriaId: categoriaId,
      incluirInativos: state.incluirInativos,
    );
  }

  void setIncluirInativos(bool incluir) {
    state = ProdutoFiltro(
      busca: state.busca,
      categoriaId: state.categoriaId,
      incluirInativos: incluir,
    );
  }
}

final produtoFiltroProvider =
    NotifierProvider<ProdutoFiltroNotifier, ProdutoFiltro>(
  ProdutoFiltroNotifier.new,
);

final produtosProvider = FutureProvider.autoDispose<List<Produto>>((ref) {
  final filtro = ref.watch(produtoFiltroProvider);
  return ref.watch(produtoRepositoryProvider).listar(
        busca: filtro.busca,
        categoriaId: filtro.categoriaId,
        incluirInativos: filtro.incluirInativos,
      );
});

final produtoPorIdProvider =
    FutureProvider.autoDispose.family<Produto?, int>((ref, id) {
  return ref.watch(produtoRepositoryProvider).buscarPorId(id);
});

final produtoTemMovimentacoesProvider =
    FutureProvider.autoDispose.family<bool, int>((ref, id) {
  return ref.watch(produtoRepositoryProvider).temMovimentacoes(id);
});

final categoriasAtivasProvider =
    FutureProvider.autoDispose<List<Categoria>>((ref) {
  return ref.watch(categoriaRepositoryProvider).listar();
});

final categoriasTodasProvider =
    FutureProvider.autoDispose<List<Categoria>>((ref) {
  return ref.watch(categoriaRepositoryProvider).listar(incluirInativas: true);
});

final unidadesAtivasProvider =
    FutureProvider.autoDispose<List<Unidade>>((ref) {
  return ref.watch(unidadeRepositoryProvider).listar();
});

final unidadesTodasProvider = FutureProvider.autoDispose<List<Unidade>>((ref) {
  return ref.watch(unidadeRepositoryProvider).listar(incluirInativas: true);
});