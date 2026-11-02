import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:projeto_2/core/utils/quantidade_utils.dart';
import 'package:projeto_2/features/relatorios/models/relatorio_dados.dart';
import 'package:projeto_2/features/relatorios/providers/relatorio_providers.dart';
import 'package:projeto_2/features/relatorios/services/relatorio_csv.dart';

class RelatoriosScreen extends ConsumerStatefulWidget {
  const RelatoriosScreen({super.key});

  @override
  ConsumerState<RelatoriosScreen> createState() => _RelatoriosScreenState();
}

class _RelatoriosScreenState extends ConsumerState<RelatoriosScreen> {
  late DateTime _inicio;
  late DateTime _fim;
  bool _exportando = false;

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

  Future<void> _selecionarPeriodo() async {
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

  Future<void> _compartilharCsv(String nome, String conteudo) async {
    setState(() => _exportando = true);
    try {
      final arquivo = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}$nome',
      );
      await arquivo.writeAsString(conteudo, encoding: const Utf8Codec());
      await SharePlus.instance.share(
        ShareParams(files: [XFile(arquivo.path)], text: nome),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível exportar o relatório.')),
      );
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
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
                ref.invalidate(movimentacoesRelatorioProvider(
                    (inicio: _inicio, fim: _fim)));
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
                  child: Text('Posição atual do estoque',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  tooltip: 'Exportar estoque em CSV',
                  onPressed: _exportando
                      ? null
                      : () => _compartilharCsv(
                            'estoque_uan.csv',
                            RelatorioCsv.estoque(linhas),
                          ),
                  icon: const Icon(Icons.file_download_outlined),
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
                  child: Text('Movimentações',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  tooltip: 'Exportar movimentações em CSV',
                  onPressed: linhas.isEmpty || _exportando
                      ? null
                      : () => _compartilharCsv(
                            'movimentacoes_${_data(_inicio).replaceAll('/', '-')}_'
                            '${_data(_fim).replaceAll('/', '-')}.csv',
                            RelatorioCsv.movimentacoes(linhas),
                          ),
                  icon: const Icon(Icons.file_download_outlined),
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
    final estoque = ref.watch(estoqueRelatorioProvider);
    final periodo = (inicio: _inicio, fim: _fim);
    final movimentacoes = ref.watch(movimentacoesRelatorioProvider(periodo));

    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(estoqueRelatorioProvider);
          ref.invalidate(movimentacoesRelatorioProvider(periodo));
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.date_range),
                title: const Text('Período das movimentações'),
                subtitle: Text('${_data(_inicio)} a ${_data(_fim)}'),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: _selecionarPeriodo,
              ),
            ),
            const SizedBox(height: 8),
            _estado(estoque, _cartaoEstoque),
            const SizedBox(height: 8),
            _estado(movimentacoes, _cartaoMovimentacoes),
          ],
        ),
      ),
    );
  }
}
