import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:projeto_2/core/utils/texto_utils.dart';
import 'package:projeto_2/features/produtos/models/categoria.dart';
import 'package:projeto_2/features/produtos/models/produto.dart';
import 'package:projeto_2/features/produtos/providers/produto_providers.dart';

class ProdutosListaView extends ConsumerWidget {
  const ProdutosListaView({super.key, this.aoTocar, this.mostrarCategorias = true});

  final void Function(Produto produto)? aoTocar;
  final bool mostrarCategorias;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtro = ref.watch(produtoFiltroProvider);
    final produtosAsync = ref.watch(produtosProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            autofocus: false,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            decoration: const InputDecoration(
              hintText: 'Buscar produto',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (texto) =>
                ref.read(produtoFiltroProvider.notifier).setBusca(texto),
          ),
        ),
        const SizedBox(height: 8),
        if (mostrarCategorias) ...[
          _CategoriaChips(),
          const SizedBox(height: 8),
        ],
        if (!mostrarCategorias && filtro.categoriaId != null) ...[
          _CategoriaFiltroChip(categoriaId: filtro.categoriaId!),
          const SizedBox(height: 8),
        ],
        SwitchListTile(
          title: const Text('Mostrar inativos'),
          value: filtro.incluirInativos,
          onChanged: (valor) =>
              ref.read(produtoFiltroProvider.notifier).setIncluirInativos(valor),
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        const Divider(height: 1),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(produtosProvider),
            child: produtosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(
                child: Text('Erro ao carregar produtos.'),
              ),
              data: (produtos) {
                if (produtos.isEmpty) {
                  final semFiltro =
                      filtro.busca.isEmpty &&
                      filtro.categoriaId == null &&
                      !filtro.incluirInativos;
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Nenhum produto encontrado.'),
                        if (semFiltro) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Toque em + para cadastrar o primeiro produto.',
                          ),
                        ],
                      ],
                    ),
                  );
                }

                if (filtro.categoriaId == null) {
                  return _listaAgrupada(produtos, context, aoTocar: aoTocar);
                }

                return _listaSimples(produtos, context, aoTocar: aoTocar);
              },
            ),
          ),
        ),
      ],
    );
  }
}

Widget _listaSimples(List<Produto> produtos, BuildContext context,
    {void Function(Produto produto)? aoTocar}) {
  return ListView.builder(
    itemCount: produtos.length,
    itemBuilder: (context, index) {
      final produto = produtos[index];
      return Card(
        color: produto.ativo ? null : Colors.grey.shade200,
        child: ListTile(
          title: Text(
            produto.nome,
            style: TextStyle(
              color: produto.ativo ? null : Colors.grey,
            ),
          ),
          subtitle: Text(produto.categoriaNome),
          trailing: Text(produto.saldoFormatado),
          onTap: () {
            if (aoTocar != null) {
              aoTocar!(produto);
            } else {
              context.push('/produtos/${produto.id}/editar');
            }
          },
        ),
      );
    },
  );
}

Widget _listaAgrupada(List<Produto> produtos, BuildContext context,
    {void Function(Produto produto)? aoTocar}) {
  final agrupado = <String, List<Produto>>{};
  for (final p in produtos) {
    agrupado.putIfAbsent(p.categoriaNome, () => []).add(p);
  }

  final categoriasOrdenadas = agrupado.keys.toList()
    ..sort((a, b) => TextoUtils.normalizar(a).compareTo(TextoUtils.normalizar(b)));

  final widgets = <Widget>[];
  for (final categoriaNome in categoriasOrdenadas) {
    final produtosCategoria = agrupado[categoriaNome]!;
    produtosCategoria.sort(
      (a, b) => TextoUtils.normalizar(a.nome).compareTo(TextoUtils.normalizar(b.nome)),
    );
    widgets.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Text(
          '$categoriaNome (${produtosCategoria.length})',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
    widgets.addAll(produtosCategoria.map(
      (p) => Card(
        color: p.ativo ? null : Colors.grey.shade200,
        child: ListTile(
          title: Text(
            p.nome,
            style: TextStyle(
              color: p.ativo ? null : Colors.grey,
            ),
          ),
          trailing: Text(p.saldoFormatado),
          onTap: () {
            if (aoTocar != null) {
              aoTocar!(p);
            } else {
              context.push('/produtos/${p.id}/movimentar');
            }
          },
        ),
      ),
    ));
    widgets.add(const Divider(height: 1));
  }

  return ListView(children: widgets);
}

class _CategoriaChips extends ConsumerWidget {
  const _CategoriaChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtro = ref.watch(produtoFiltroProvider);
    final categoriasAsync = ref.watch(categoriasAtivasProvider);

    return categoriasAsync.when(
      data: (categorias) {
        return SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ChoiceChip(
                label: const Text('Todas'),
                selected: filtro.categoriaId == null,
                onSelected: (_) =>
                    ref.read(produtoFiltroProvider.notifier).setCategoria(null),
              ),
              const SizedBox(width: 8),
              for (final categoria in categorias)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(categoria.nome),
                    selected: filtro.categoriaId == categoria.id,
                    onSelected: (_) =>
                        ref.read(produtoFiltroProvider.notifier).setCategoria(categoria.id),
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 40),
      error: (_, __) => const SizedBox(height: 40),
    );
  }
}

class _CategoriaFiltroChip extends ConsumerWidget {
  const _CategoriaFiltroChip({required this.categoriaId});

  final int categoriaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ativasAsync = ref.watch(categoriasAtivasProvider);
    final todasAsync = ref.watch(categoriasTodasProvider);

    String? nome;
    final ativasData = ativasAsync.value;
    if (ativasData != null) {
      nome = _nomeCategoria(ativasData, categoriaId);
    }
    if (nome == null) {
      final todasData = todasAsync.value;
      if (todasData != null) {
        nome = _nomeCategoria(todasData, categoriaId);
      }
    }

    if (nome == null) {
      if (ativasAsync.isLoading || todasAsync.isLoading) {
        return const SizedBox(
          height: 32,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      }
      return const SizedBox.shrink();
    }

    return Chip(
      label: Text('Categoria: $nome'),
      deleteIcon: const Icon(Icons.close, size: 18),
      onDeleted: () =>
          ref.read(produtoFiltroProvider.notifier).setCategoria(null),
    );
  }

  static String? _nomeCategoria(List<Categoria> categorias, int id) {
    for (final categoria in categorias) {
      if (categoria.id == id) {
        return categoria.nome;
      }
    }
    return null;
  }
}