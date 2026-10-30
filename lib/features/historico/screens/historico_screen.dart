import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:projeto_2/core/utils/app_exception.dart';
import 'package:projeto_2/core/utils/quantidade_utils.dart';
import 'package:projeto_2/features/historico/models/historico_filtro.dart';
import 'package:projeto_2/features/historico/providers/historico_providers.dart';
import 'package:projeto_2/features/historico/repositories/historico_repository.dart';
import 'package:projeto_2/features/movimentacoes/models/movimentacao.dart';
import 'package:projeto_2/features/produtos/models/produto.dart';
import 'package:projeto_2/features/produtos/providers/produto_providers.dart';
import 'package:projeto_2/features/produtos/widgets/produtos_lista_view.dart';

/// Tela de histórico de movimentações de estoque.
class HistoricoScreen extends ConsumerWidget {
  const HistoricoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtro = ref.watch(historicoFiltroProvider);
    final historicoAsync = ref.watch(historicoProvider);
    final produtoAsync =
        filtro.produtoId == null ? null : ref.watch(produtoPorIdProvider(filtro.produtoId!));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de movimentações'),
        actions: [
          if (filtro.temFiltro)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Limpar filtros',
              onPressed: () =>
                  ref.read(historicoFiltroProvider.notifier).limpar(),
            ),
        ],
      ),
      body: Column(
        children: [
          _Filtros(filtro: filtro, produtoAsync: produtoAsync),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(historicoProvider),
              child: historicoAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) {
                  final mensagem = error is AppException
                      ? error.message
                      : 'Erro inesperado ao carregar o histórico.';
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(mensagem),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(historicoProvider),
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  );
                },
                data: (pagina) {
                    if (pagina.itens.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Nenhuma movimentação encontrada.'),
                            if (filtro.temFiltro) ...[
                              const SizedBox(height: 8),
                              const Text('Tente mudar ou limpar os filtros.'),
                            ],
                          ],
                        ),
                      );
                    }
                    return _HistoricoLista(pagina: pagina);
                  },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Filtros do histórico (produto, período e tipo), em listas roláveis horizontalmente.
class _Filtros extends ConsumerWidget {
  const _Filtros({required this.filtro, required this.produtoAsync});

  final HistoricoFiltro filtro;
  final AsyncValue<Produto?>? produtoAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoje = DateTime.now();
    final hojeInicio = DateTime(hoje.year, hoje.month, hoje.day);
    final diaSeis = hojeInicio.subtract(const Duration(days: 6));
    final diaVinteENove = hojeInicio.subtract(const Duration(days: 29));
    final mesInicio = DateTime(hoje.year, hoje.month, 1);

    final temPeriodo = filtro.inicio != null || filtro.fim != null;
    final tudoSelecionado = filtro.inicio == null && filtro.fim == null;
    final hojeSelecionado = filtro.inicio != null &&
        filtro.fim != null &&
        _mesmoDia(filtro.inicio!, hoje) &&
        _mesmoDia(filtro.fim!, hoje);
    final seteSelecionado = filtro.inicio != null &&
        filtro.fim != null &&
        _mesmoDia(filtro.inicio!, diaSeis) &&
        _mesmoDia(filtro.fim!, hoje);
    final trintaSelecionado = filtro.inicio != null &&
        filtro.fim != null &&
        _mesmoDia(filtro.inicio!, diaVinteENove) &&
        _mesmoDia(filtro.fim!, hoje);
    final mesSelecionado = filtro.inicio != null &&
        filtro.fim != null &&
        _mesmoDia(filtro.inicio!, mesInicio) &&
        _mesmoDia(filtro.fim!, hoje);
    final personalizadoSelecionado =
        temPeriodo &&
        !tudoSelecionado &&
        !hojeSelecionado &&
        !seteSelecionado &&
        !trintaSelecionado &&
        !mesSelecionado;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text(
            'Produto',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _ProdutoFiltroChip(filtro: filtro, produtoAsync: produtoAsync),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text(
            'Período',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              const SizedBox(width: 4),
              ChoiceChip(
                label: const Text('Tudo'),
                selected: tudoSelecionado,
                onSelected: (_) =>
                    ref.read(historicoFiltroProvider.notifier).setPeriodo(null, null),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Hoje'),
                selected: hojeSelecionado,
                onSelected: (_) => ref
                    .read(historicoFiltroProvider.notifier)
                    .setPeriodo(hojeInicio, hojeInicio),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('7 dias'),
                selected: seteSelecionado,
                onSelected: (_) => ref
                    .read(historicoFiltroProvider.notifier)
                    .setPeriodo(diaSeis, hojeInicio),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('30 dias'),
                selected: trintaSelecionado,
                onSelected: (_) => ref
                    .read(historicoFiltroProvider.notifier)
                    .setPeriodo(diaVinteENove, hojeInicio),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Este mês'),
                selected: mesSelecionado,
                onSelected: (_) => ref
                    .read(historicoFiltroProvider.notifier)
                    .setPeriodo(mesInicio, hojeInicio),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(_labelPersonalizado(filtro)),
                selected: personalizadoSelecionado,
                onSelected: (_) => _abrirSeletorPeriodo(context, ref),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text(
            'Tipo',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              const SizedBox(width: 4),
              ChoiceChip(
                label: const Text('Todos'),
                selected: filtro.tipo == null,
                onSelected: (_) =>
                    ref.read(historicoFiltroProvider.notifier).setTipo(null),
              ),
              const SizedBox(width: 8),
              for (final tipo in TipoMovimentacao.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(tipo.rotulo),
                    selected: filtro.tipo == tipo,
                    onSelected: (_) => ref
                        .read(historicoFiltroProvider.notifier)
                        .setTipo(tipo),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _labelPersonalizado(HistoricoFiltro f) {
    if (f.inicio != null && f.fim != null) {
      return 'Personalizado (${_ddMmAaa(f.inicio!)} a ${_ddMmAaa(f.fim!)})';
    }
    return 'Personalizado';
  }

  Future<void> _abrirSeletorPeriodo(BuildContext context, WidgetRef ref) async {
    final hoje = DateTime.now();
    final selecionado = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(hoje.year, hoje.month, hoje.day),
    );
    if (!context.mounted) return;
    if (selecionado != null) {
      ref.read(historicoFiltroProvider.notifier).setPeriodo(
        selecionado.start,
        selecionado.end,
      );
    }
  }
}

/// Chip do filtro de produto.
class _ProdutoFiltroChip extends ConsumerWidget {
  const _ProdutoFiltroChip({required this.filtro, required this.produtoAsync});

  final HistoricoFiltro filtro;
  final AsyncValue<Produto?>? produtoAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => _abrirSeletorProduto(context, ref),
      child: Chip(
        label: _label(),
        deleteIcon: filtro.produtoId == null ? null : const Icon(Icons.close, size: 18),
        onDeleted: filtro.produtoId == null
            ? null
            : () => ref.read(historicoFiltroProvider.notifier).setProduto(null),
      ),
    );
  }

  Widget _label() {
    if (filtro.produtoId == null) {
      return const Text('Todos os produtos');
    }
    return produtoAsync!.when(
      data: (produto) =>
          Text(produto == null ? 'Produto não encontrado' : produto.nome),
      loading: () => const Text('Carregando...'),
      error: (_, _) => const Text('Erro ao carregar'),
    );
  }

  Future<void> _abrirSeletorProduto(BuildContext context, WidgetRef ref) async {
    final produto = await showModalBottomSheet<Produto>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: ProdutosListaView(
          aoTocar: (p) => Navigator.of(sheetContext).pop(p),
        ),
      ),
    );
    if (!context.mounted) return;
    if (produto != null) {
      ref.read(historicoFiltroProvider.notifier).setProduto(produto.id);
    }
  }
}

/// Lista de movimentações agrupada por dia.
class _HistoricoLista extends ConsumerWidget {
  const _HistoricoLista({required this.pagina});

  final HistoricoPagina pagina;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      itemCount: pagina.itens.length + (pagina.temMais ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == pagina.itens.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: OutlinedButton(
                onPressed: () =>
                    ref.read(historicoFiltroProvider.notifier).maisItens(),
                child: const Text('Carregar mais'),
              ),
            ),
          );
        }
        final item = pagina.itens[index];
        final primeiroDoDia = index == 0 ||
            !_mesmoDia(
              pagina.itens[index - 1].movimentacao.dataHora,
              item.movimentacao.dataHora,
            );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (primeiroDoDia)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Text(
                  _ddMmAaa(item.movimentacao.dataHora),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            _historicoItem(item),
          ],
        );
      },
    );
  }
}

/// Um item da lista de histórico.
Widget _historicoItem(HistoricoItem item) {
  final m = item.movimentacao;
  final cor = m.delta > 0 ? Colors.green : Colors.red;
  final sinal = m.delta > 0 ? '+' : '-';
  final quantidade =
      '$sinal${QuantidadeUtils.format(m.delta.abs(), fracionavel: item.fracionavel)} $item.unidadeSigla';
  final saldoTexto =
      'Saldo após: ${QuantidadeUtils.format(m.saldoApos, fracionavel: item.fracionavel)} ${item.unidadeSigla}';
  final tipoTexto = m.tipo.rotulo +
      (m.finalidade != null ? ' · ${m.finalidade!.rotulo}' : '');

  return ListTile(
    title: Text(item.produtoNome, style: const TextStyle(fontWeight: FontWeight.bold)),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Chip(
          label: Text(tipoTexto),
          labelStyle: const TextStyle(fontSize: 11),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(height: 4),
        Text(quantidade,
            style: TextStyle(color: cor, fontWeight: FontWeight.bold)),
        Text(saldoTexto),
        Text('${_hhmm(m.dataHora)}   ·   Responsável: ${m.usuarioNome ?? '-'}'),
        if (m.observacao?.isNotEmpty == true)
          Text('Observação: ${m.observacao}'),
      ],
    ),
  );
}

String _ddMmAaa(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

bool _mesmoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;


