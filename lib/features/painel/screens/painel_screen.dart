import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:projeto_2/core/utils/quantidade_utils.dart';
import 'package:projeto_2/features/painel/models/painel_dados.dart';
import 'package:projeto_2/features/painel/providers/painel_providers.dart';

/// Tela do painel com resumo, ranking de saídas e movimentação por dia.
class PainelScreen extends ConsumerStatefulWidget {
  const PainelScreen({super.key});

  @override
  ConsumerState<PainelScreen> createState() => _PainelScreenState();
}

class _PainelScreenState extends ConsumerState<PainelScreen> {
  /// Modo do ranking: false = gêneros, true = produtos.
  bool _rankingProdutos = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final atalho = ref.watch(painelAtalhoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(painelProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: PainelAtalho.values.map((a) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(a.rotulo),
                      selected: a == atalho,
                      onSelected: (_) =>
                          ref.read(painelAtalhoProvider.notifier).definir(a),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
            ref.watch(painelProvider).when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (Object error, StackTrace? stackTrace) => Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Erro ao carregar o painel.'),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: () => ref.invalidate(painelProvider),
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (dados) => _conteudo(colorScheme, dados),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conteudo(ColorScheme colorScheme, PainelDados dados) {
    if (dados.resumo.total == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Nenhuma movimentação no período.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Registre entradas e saídas para ver os gráficos.',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _cardResumo('Movimentações', dados.resumo.total.toString()),
              const SizedBox(width: 10),
              _cardResumo('Saídas', dados.resumo.saidas.toString()),
              const SizedBox(width: 10),
              _cardResumo('Perdas', dados.resumo.perdas.toString()),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _cardRanking(colorScheme, dados),
        const SizedBox(height: 24),
        _cardDias(colorScheme, dados.porDia),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'As barras contam registros; quantidades de unidades diferentes nunca são somadas.',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _cardResumo(String titulo, String valor) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 1),
              blurRadius: 2,
              color: colorScheme.shadow.withValues(alpha: 0.06),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              valor,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              titulo,
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardRanking(ColorScheme colorScheme, PainelDados dados) {
    final itens = _rankingProdutos ? dados.porProduto : dados.porCategoria;
    final titulo =
        _rankingProdutos ? 'Produtos com mais saída' : 'Gêneros com mais saída';
    final sombra = BoxShadow(
      offset: const Offset(0, 1),
      blurRadius: 2,
      color: colorScheme.shadow.withValues(alpha: 0.06),
    );
    final maxSaidas =
        itens.fold<int>(0, (maximo, item) => item.saidas > maximo ? item.saidas : maximo);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [sombra],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              _pilhaModo(colorScheme, sombra),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Número de saídas registradas',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (itens.isEmpty)
            Text(
              'Sem saídas no período.',
              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
            )
          else
            ...itens.map((item) => _linhaRanking(colorScheme, item, maxSaidas)),
        ],
      ),
    );
  }

  Widget _pilhaModo(ColorScheme colorScheme, BoxShadow sombra) {
    return Container(
      height: 32,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _opcaoModo('Gêneros', !_rankingProdutos, colorScheme, sombra, () {
            setState(() => _rankingProdutos = false);
          }),
          _opcaoModo('Produtos', _rankingProdutos, colorScheme, sombra, () {
            setState(() => _rankingProdutos = true);
          }),
        ],
      ),
    );
  }

  Widget _opcaoModo(
    String texto,
    bool selecionado,
    ColorScheme colorScheme,
    BoxShadow sombra,
    VoidCallback onTap,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Semantics(
        button: true,
        selected: selecionado,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: selecionado
              ? BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [sombra],
                )
              : null,
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selecionado ? FontWeight.w600 : FontWeight.w400,
              color: selecionado
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _linhaRanking(ColorScheme colorScheme, ItemRanking item, int maxSaidas) {
    final saidas = item.saidas;
    final fator = saidas > 0 && maxSaidas > 0
        ? (saidas / maxSaidas).clamp(0.04, 1.0)
        : 0.0;

    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.nome,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                if (_rankingProdutos) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${QuantidadeUtils.format(item.quantidade ?? 0, fracionavel: item.fracionavel)} ${item.unidadeSigla ?? ''}'.trim(),
                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(5),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fator,
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 28,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                saidas.toString(),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardDias(ColorScheme colorScheme, List<DiaMovimento> dias) {
    final sombra = BoxShadow(
      offset: const Offset(0, 1),
      blurRadius: 2,
      color: colorScheme.shadow.withValues(alpha: 0.06),
    );

    int maxTotal = 0;
    for (final d in dias) {
      if (d.total > maxTotal) maxTotal = d.total;
    }
    final diaMax = maxTotal > 0 ? dias.firstWhere((d) => d.total == maxTotal) : null;
    final maisDeSete = dias.length > 7;
    final espaco = maisDeSete ? 2.0 : 10.0;
    final raio = maisDeSete ? 6.0 : 10.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [sombra],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dias com mais movimentação',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(dias.length, (i) {
                final dia = dias[i];
                final isMax = diaMax != null && dia.dia == diaMax.dia;
                final altura = _alturaBarra(dia.total, maxTotal);
                final mostrarValor = !maisDeSete || isMax;
                final mostrarRotulo =
                    !maisDeSete || i == 0 || i % 5 == 0 || i == dias.length - 1;
                return Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (mostrarValor)
                        Text(
                          dia.total.toString(),
                          style: TextStyle(
                            fontSize: isMax ? 12 : 11,
                            fontWeight: isMax ? FontWeight.w700 : FontWeight.w400,
                            color: isMax
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      const SizedBox(height: 6),
                      Semantics(
                        label:
                            '${_dois(dia.dia.day)}/${_dois(dia.dia.month)}: ${dia.total} movimentações',
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: espaco / 2),
                          height: altura,
                          decoration: BoxDecoration(
                            color: isMax
                                ? colorScheme.primary
                                : colorScheme.primary.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(raio),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        mostrarRotulo
                            ? (maisDeSete
                                ? '${dia.dia.day}'
                                : _abreviaDiaSemana(dia.dia.weekday))
                            : '',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  double _alturaBarra(int total, int maxTotal) {
    if (maxTotal == 0 || total == 0) return 2;
    return (total / maxTotal * 100).clamp(3.0, 100.0);
  }

  String _dois(int n) => n.toString().padLeft(2, '0');

  String _abreviaDiaSemana(int weekday) {
    switch (weekday) {
      case 1:
        return 'Seg';
      case 2:
        return 'Ter';
      case 3:
        return 'Qua';
      case 4:
        return 'Qui';
      case 5:
        return 'Sex';
      case 6:
        return 'Sáb';
      case 7:
        return 'Dom';
      default:
        return '';
    }
  }
}
