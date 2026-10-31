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

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: TextField(
            autofocus: false,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            decoration: InputDecoration(
              filled: true,
              fillColor: colorScheme.surfaceContainerHigh,
              hintText: 'Buscar produto',
              prefixIcon: Icon(
                Icons.search,
                color: colorScheme.onSurfaceVariant,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: Row(
            children: [
              Text(
                'Mostrar inativos',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Switch(
                value: filtro.incluirInativos,
                onChanged: (valor) =>
                    ref.read(produtoFiltroProvider.notifier).setIncluirInativos(valor),
              ),
            ],
          ),
        ),
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
                  return _listaAgrupada(context, produtos, aoTocar: aoTocar);
                }

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(top: 8, bottom: 96),
                  children: [
                    _ListaCard(
                      children: _itensComLinhas(
                        context,
                        produtos,
                        aoTocar: aoTocar,
                        mostrarCategoria: true,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

Widget _listaAgrupada(BuildContext context, List<Produto> produtos,
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
        padding: const EdgeInsets.fromLTRB(28, 18, 28, 8),
        child: Text(
          '${categoriaNome.toUpperCase()} · ${produtosCategoria.length}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
    widgets.add(
      _ListaCard(
        children: _itensComLinhas(
          context,
          produtosCategoria,
          aoTocar: aoTocar,
          mostrarCategoria: false,
        ),
      ),
    );
  }

  return ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.only(bottom: 96),
    children: widgets,
  );
}

class _ListaCard extends StatelessWidget {
  const _ListaCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 1),
            blurRadius: 2,
            color: colorScheme.shadow.withValues(alpha: 0.06),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

List<Widget> _itensComLinhas(
  BuildContext context,
  List<Produto> produtos, {
  required void Function(Produto produto)? aoTocar,
  required bool mostrarCategoria,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final itens = <Widget>[];
  for (var i = 0; i < produtos.length; i++) {
    if (i > 0) {
      itens.add(
        Container(height: 1, color: colorScheme.outlineVariant),
      );
    }
    itens.add(
      _ProdutoItem(
        produto: produtos[i],
        aoTocar: aoTocar,
        mostrarCategoria: mostrarCategoria,
      ),
    );
  }
  return itens;
}

class _ProdutoItem extends StatelessWidget {
  const _ProdutoItem({
    required this.produto,
    required this.aoTocar,
    this.mostrarCategoria = false,
  });

  final Produto produto;
  final void Function(Produto produto)? aoTocar;
  final bool mostrarCategoria;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ativo = produto.ativo;
    final saldoZero = produto.saldo == 0;
    return InkWell(
      onTap: () {
        if (aoTocar != null) {
          aoTocar!(produto);
        } else {
          context.push('/produtos/${produto.id}/movimentar');
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  produto.nome,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: ativo ? null : colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (mostrarCategoria) ...[
                  const SizedBox(height: 4),
                  Text(
                    produto.categoriaNome,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (!ativo) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Inativo',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (saldoZero || !ativo)
                  ? colorScheme.surfaceContainerHigh
                  : colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              produto.saldoFormatado,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: (saldoZero || !ativo)
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
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
              const SizedBox(width: 20),
              for (final categoria in categorias)
                Padding(
                  padding: const EdgeInsets.only(right: 20),
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
