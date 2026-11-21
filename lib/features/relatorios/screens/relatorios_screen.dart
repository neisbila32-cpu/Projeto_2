import 'menu_pdf.dart';

import 'package:flutter/material.dart';
import 'package:projeto_2/features/home/widgets/app_drawer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:projeto_2/core/utils/quantidade_utils.dart';
import 'package:projeto_2/features/relatorios/models/relatorio_dados.dart';
import 'package:projeto_2/features/relatorios/providers/relatorio_providers.dart';
import 'package:projeto_2/features/relatorios/services/relatorio_pdf.dart';

enum _ModoPeriodoRelatorio { dia, intervalo }

class RelatoriosScreen extends StatelessWidget {
  const RelatoriosScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    drawer: const AppDrawer(),
    appBar: AppBar(
      leading: drawerMenuButton(context),
      title: const Text('Relatórios'),
    ),
    body: ListView(
      children: [
        for (final estoque in [true, false])
          ListTile(
            leading: Icon(
              estoque ? Icons.inventory_2_outlined : Icons.swap_vert,
            ),
            title: Text(estoque ? 'Posição atual do estoque' : 'Movimentações'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => _DetalheRelatorio(estoque: estoque),
              ),
            ),
          ),
      ],
    ),
  );
}

class _DetalheRelatorio extends ConsumerStatefulWidget {
  const _DetalheRelatorio({required this.estoque});
  final bool estoque;

  @override
  ConsumerState<_DetalheRelatorio> createState() => _RelatoriosScreenState();
}

class _RelatoriosScreenState extends ConsumerState<_DetalheRelatorio> {
  late DateTime _inicio;
  late DateTime _fim;
  _ModoPeriodoRelatorio _modoPeriodo = _ModoPeriodoRelatorio.intervalo;

  @override
  void initState() {
    super.initState();
    final hoje = DateTime.now();
    _fim = DateTime(hoje.year, hoje.month, hoje.day);
    _inicio = DateTime(hoje.year, hoje.month, 1);
  }

  String _data(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/'
      '${data.month.toString().padLeft(2, '0')}/${data.year}';

  String _carimbo(DateTime data) =>
      '${data.year}-${data.month.toString().padLeft(2, '0')}-'
      '${data.day.toString().padLeft(2, '0')}_'
      '${data.hour.toString().padLeft(2, '0')}-'
      '${data.minute.toString().padLeft(2, '0')}-'
      '${data.second.toString().padLeft(2, '0')}';

  Future<void> _selecionarDia() async {
    final hoje = DateTime.now();
    final selecionado = await showDatePicker(
      context: context,
      initialDate: _fim.isAfter(hoje) ? hoje : _fim,
      firstDate: DateTime(2020),
      lastDate: DateTime(hoje.year, hoje.month, hoje.day),
      helpText: 'Selecione o dia do relatório',
      confirmText: 'Aplicar',
    );
    if (!mounted || selecionado == null) return;
    setState(() {
      _inicio = DateTime(selecionado.year, selecionado.month, selecionado.day);
      _fim = _inicio;
    });
  }

  Future<void> _selecionarIntervalo() async {
    final hoje = DateTime.now();
    final selecionado = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(hoje.year, hoje.month, hoje.day),
      initialDateRange: DateTimeRange(start: _inicio, end: _fim),
      helpText: 'Selecione o período do relatório',
      saveText: 'Aplicar',
    );
    if (!mounted || selecionado == null) return;
    setState(() {
      _inicio = selecionado.start;
      _fim = selecionado.end;
    });
  }

  Widget _estado<T>(AsyncValue<T> valor, Widget Function(T dados) conteudo) {
    return valor.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Não foi possível carregar o relatório.'),
            TextButton(
              onPressed: () {
                ref.invalidate(estoqueRelatorioProvider);
                ref.invalidate(
                  movimentacoesRelatorioProvider((inicio: _inicio, fim: _fim)),
                );
              },
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
      data: conteudo,
    );
  }

  Widget _cartaoEstoque(List<LinhaEstoqueRelatorio> linhas) {
    final ativos = linhas.where((l) => l.ativo).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Posição atual do estoque',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                MenuPdf(
                  gerar: () async {
                    final agora = DateTime.now();
                    return (
                      nome: 'relatorio_estoque_gerado_${_carimbo(agora)}.pdf',
                      bytes: await RelatorioPdf.estoque(
                        linhas,
                        geradoEm: agora,
                      ),
                    );
                  },
                ),
              ],
            ),
            Text('$ativos produtos ativos · ${linhas.length} no total'),
            const SizedBox(height: 8),
            if (linhas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Nenhum produto cadastrado.'),
              )
            else
              for (final linha in linhas)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(linha.produtoNome),
                  subtitle: Text(
                    '${linha.categoriaNome} · ${linha.ativo ? 'Ativo' : 'Inativo'}',
                  ),
                  trailing: Text(
                    '${QuantidadeUtils.format(linha.saldo, fracionavel: linha.fracionavel)} ${linha.unidadeSigla}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _cartaoMovimentacoes(List<LinhaMovimentacaoRelatorio> linhas) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Movimentações',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                MenuPdf(
                  gerar: linhas.isEmpty
                      ? null
                      : () async {
                          final agora = DateTime.now();
                          return (
                            nome:
                                'relatorio_movimentacoes_${_carimbo(_inicio)}_a_${_carimbo(_fim)}_gerado_${_carimbo(agora)}.pdf',
                            bytes: await RelatorioPdf.movimentacoes(
                              linhas,
                              inicio: _inicio,
                              fim: _fim,
                              geradoEm: agora,
                            ),
                          );
                        },
                ),
              ],
            ),
            Text('${linhas.length} movimentações no período'),
            const SizedBox(height: 8),
            if (linhas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Nenhuma movimentação neste período.'),
              )
            else
              for (final linha in linhas)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(linha.produtoNome),
                  subtitle: Text(
                    '${_data(linha.dataHora)} · ${linha.tipo} · ${linha.usuarioNome}',
                  ),
                  trailing: Text(
                    '${linha.delta > 0 ? '+' : ''}${QuantidadeUtils.format(linha.delta, fracionavel: linha.fracionavel)} ${linha.unidadeSigla}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final periodo = (inicio: _inicio, fim: _fim);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.estoque ? 'Posição atual do estoque' : 'Movimentações',
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(estoqueRelatorioProvider);
          ref.invalidate(movimentacoesRelatorioProvider(periodo));
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.estoque)
              _estado(ref.watch(estoqueRelatorioProvider), _cartaoEstoque)
            else ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.date_range),
                  title: Text(
                    _modoPeriodo == _ModoPeriodoRelatorio.dia
                        ? 'Dia das movimentações'
                        : 'Intervalo das movimentações',
                  ),
                  subtitle: Text(
                    _modoPeriodo == _ModoPeriodoRelatorio.dia
                        ? 'Dia selecionado: ${_data(_inicio)}'
                        : 'Período selecionado: ${_data(_inicio)} a ${_data(_fim)}',
                  ),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: _modoPeriodo == _ModoPeriodoRelatorio.dia
                      ? _selecionarDia
                      : _selecionarIntervalo,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<_ModoPeriodoRelatorio>(
                segments: const [
                  ButtonSegment(
                    value: _ModoPeriodoRelatorio.dia,
                    label: Text('Um dia'),
                    icon: Icon(Icons.today_outlined),
                  ),
                  ButtonSegment(
                    value: _ModoPeriodoRelatorio.intervalo,
                    label: Text('Intervalo'),
                    icon: Icon(Icons.date_range_outlined),
                  ),
                ],
                selected: {_modoPeriodo},
                onSelectionChanged: (selecionado) {
                  final modo = selecionado.first;
                  setState(() {
                    _modoPeriodo = modo;
                    if (modo == _ModoPeriodoRelatorio.dia) _fim = _inicio;
                  });
                },
              ),
              const SizedBox(height: 8),
              _estado(
                ref.watch(movimentacoesRelatorioProvider(periodo)),
                _cartaoMovimentacoes,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
