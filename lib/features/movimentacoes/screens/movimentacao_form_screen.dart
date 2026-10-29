import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:projeto_2/core/utils/app_exception.dart';
import 'package:projeto_2/core/utils/quantidade_utils.dart';
import 'package:projeto_2/features/auth/providers/auth_providers.dart';
import 'package:projeto_2/features/movimentacoes/models/movimentacao.dart';
import 'package:projeto_2/features/historico/providers/historico_providers.dart';
import 'package:projeto_2/features/movimentacoes/providers/movimentacao_providers.dart';
import 'package:projeto_2/features/produtos/providers/produto_providers.dart';

class MovimentacaoFormScreen extends ConsumerStatefulWidget {
  final int produtoId;

  const MovimentacaoFormScreen({super.key, required this.produtoId});

  @override
  ConsumerState<MovimentacaoFormScreen> createState() =>
      _MovimentacaoFormScreenState();
}

class _MovimentacaoFormScreenState extends ConsumerState<MovimentacaoFormScreen> {
  TipoMovimentacao _tipo = TipoMovimentacao.entrada;
  FinalidadeSaida? _finalidade;
  final _qtdController = TextEditingController();
  final _obsController = TextEditingController();
  bool _carregando = false;

  @override
  void dispose() {
    _qtdController.dispose();
    _obsController.dispose();
    super.dispose();
  }

  String _formatarDataHora(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatarDelta(int delta, bool fracionavel, String sigla) {
    final sinal = delta >= 0 ? '+' : '−';
    return '$sinal${QuantidadeUtils.format(delta.abs(), fracionavel: fracionavel)} $sigla';
  }

  Future<void> _registrar() async {
    final qtd = QuantidadeUtils.parse(
      _qtdController.text,
      fracionavel: true,
    );
    if (qtd == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe uma quantidade válida.')),
      );
      return;
    }

    final usuario = ref.read(sessionProvider).value;
    if (usuario == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário não encontrado.')),
      );
      return;
    }

    setState(() => _carregando = true);

    try {
      await ref.read(movimentacaoRepositoryProvider).registrar(
        produtoId: widget.produtoId,
        tipo: _tipo,
        valor: qtd,
        usuarioId: usuario.id,
        finalidade: _tipo == TipoMovimentacao.saida ? _finalidade : null,
        observacao: _obsController.text.trim().isEmpty
            ? null
            : _obsController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Movimentação registrada. Novo saldo: ${QuantidadeUtils.format(qtd, fracionavel: true)}',
          ),
        ),
      );
      _qtdController.clear();
      _obsController.clear();
      setState(() {
        _tipo = TipoMovimentacao.entrada;
        _finalidade = null;
      });

      ref.invalidate(produtosProvider);
      ref.invalidate(produtoPorIdProvider(widget.produtoId));
      ref.invalidate(produtoTemMovimentacoesProvider(widget.produtoId));
      ref.invalidate(ultimasMovimentacoesProvider(widget.produtoId));
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro inesperado. Tente novamente.')),
      );
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final produtoAsync = ref.watch(produtoPorIdProvider(widget.produtoId));
    final usuario = ref.watch(sessionProvider).value;
    final movimentacoesAsync = ref.watch(ultimasMovimentacoesProvider(widget.produtoId));

    return produtoAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Scaffold(
        body: Center(child: Text('Erro ao carregar produto.')),
      ),
      data: (produto) {
        if (produto == null) {
          return const Scaffold(
            body: Center(child: Text('Produto não encontrado.')),
          );
        }

        final ativo = produto.ativo;
        final fracionavel = produto.unidadeFracionavel;
        final sigla = produto.unidadeSigla;
        final rotuloQtd = _tipo == TipoMovimentacao.ajuste
            ? 'Novo saldo'
            : 'Quantidade';

        return Scaffold(
          appBar: AppBar(
            title: const Text('Movimentar estoque'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Editar produto',
                onPressed: () async {
                  await context.push('/produtos/${widget.produtoId}/editar');
                  if (!mounted) return;
                  ref.invalidate(produtoPorIdProvider(widget.produtoId));
                  ref.invalidate(produtosProvider);
                },
              ),
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: 'Ver histórico',
                onPressed: () {
                  ref.read(historicoFiltroProvider.notifier).limpar();
                  ref
                      .read(historicoFiltroProvider.notifier)
                      .setProduto(widget.produtoId);
                  context.push('/historico');
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          produto.nome,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(produto.categoriaNome),
                        const SizedBox(height: 8),
                        Text(
                          'Saldo atual: ${QuantidadeUtils.format(produto.saldo, fracionavel: fracionavel)} $sigla',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tipo de movimentação',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SegmentedButton<TipoMovimentacao>(
                  segments: const [
                    ButtonSegment(
                      value: TipoMovimentacao.entrada,
                      label: Text('Entrada'),
                      icon: Icon(Icons.add),
                    ),
                    ButtonSegment(
                      value: TipoMovimentacao.saida,
                      label: Text('Saída'),
                      icon: Icon(Icons.remove),
                    ),
                    ButtonSegment(
                      value: TipoMovimentacao.perda,
                      label: Text('Perda'),
                      icon: Icon(Icons.delete),
                    ),
                    ButtonSegment(
                      value: TipoMovimentacao.ajuste,
                      label: Text('Ajuste'),
                      icon: Icon(Icons.edit),
                    ),
                  ],
                  selected: {_tipo},
                  onSelectionChanged: ativo && !_carregando
                      ? (selecao) {
                          if (selecao.isNotEmpty) {
                            setState(() => _tipo = selecao.first);
                          }
                        }
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _qtdController,
                  decoration: InputDecoration(
                    labelText: rotuloQtd,
                    suffixText: sigla,
                  ),
                  keyboardType: fracionavel
                      ? TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.number,
                  enabled: ativo && !_carregando,
                ),
                if (_tipo == TipoMovimentacao.saida) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<FinalidadeSaida>(
                    value: _finalidade,
                    items: const [
                      DropdownMenuItem(
                        value: FinalidadeSaida.producao,
                        child: Text('Produção'),
                      ),
                      DropdownMenuItem(
                        value: FinalidadeSaida.transferencia,
                        child: Text('Transferência'),
                      ),
                      DropdownMenuItem(
                        value: FinalidadeSaida.outra,
                        child: Text('Outra'),
                      ),
                    ],
                    onChanged: ativo && !_carregando
                        ? (valor) => setState(() => _finalidade = valor)
                        : null,
                    decoration: const InputDecoration(labelText: 'Finalidade'),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _obsController,
                  decoration: InputDecoration(
                    labelText: _tipo == TipoMovimentacao.perda
                        ? 'Motivo da perda'
                        : _tipo == TipoMovimentacao.ajuste
                            ? 'Justificativa'
                            : 'Observação',
                  ),
                  maxLines: 2,
                  enabled: ativo && !_carregando,
                ),
                const SizedBox(height: 16),
                Text(
                  'Responsável: ${usuario?.nome ?? ''}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (ativo && !_carregando) ? _registrar : null,
                    child: _carregando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Registrar'),
                  ),
                ),
                if (!ativo) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Produto inativo não pode ser movimentado.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                const Text(
                  'Últimas movimentações',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                movimentacoesAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (_, __) => const Center(
                    child: Text('Erro ao carregar movimentações.'),
                  ),
                  data: (movimentacoes) {
                    if (movimentacoes.isEmpty) {
                      return const Center(
                        child: Text('Nenhuma movimentação ainda.'),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: movimentacoes.length,
                      itemBuilder: (context, index) {
                        final m = movimentacoes[index];
                        final tipoLabel = m.tipo.rotulo;
                        final finalidadeLabel =
                            m.finalidade != null
                                ? ' (${m.finalidade!.rotulo})'
                                : '';
                        final deltaLabel = _formatarDelta(
                          m.delta,
                          fracionavel,
                          sigla,
                        );
                        return Card(
                          child: ListTile(
                            title: Text('$tipoLabel$finalidadeLabel'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$deltaLabel · saldo após: ${QuantidadeUtils.format(m.saldoApos, fracionavel: fracionavel)} $sigla',
                                ),
                                Text(
                                  '${_formatarDataHora(m.dataHora)} · ${m.usuarioNome ?? ''}',
                                ),
                                if (m.observacao != null && m.observacao!.isNotEmpty)
                                  Text('Obs: ${m.observacao}'),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}