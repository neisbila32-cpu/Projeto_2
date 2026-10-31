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
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        produto.categoriaNome.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        produto.nome,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            'Saldo atual',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${QuantidadeUtils.format(produto.saldo, fracionavel: fracionavel)} $sigla',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.primary,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Tipo de movimentação',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                            ),
                  child: Row(
                    children: [
                      _TipoSegment(
                        rotulo: 'Entrada',
                        selecionado: _tipo == TipoMovimentacao.entrada,
                        ativo: ativo && !_carregando,
                        onSelecionado: () =>
                            setState(() => _tipo = TipoMovimentacao.entrada),
                      ),
                      _TipoSegment(
                        rotulo: 'Saída',
                        selecionado: _tipo == TipoMovimentacao.saida,
                        ativo: ativo && !_carregando,
                        onSelecionado: () =>
                            setState(() => _tipo = TipoMovimentacao.saida),
                      ),
                      _TipoSegment(
                        rotulo: 'Perda',
                        selecionado: _tipo == TipoMovimentacao.perda,
                        ativo: ativo && !_carregando,
                        onSelecionado: () =>
                            setState(() => _tipo = TipoMovimentacao.perda),
                      ),
                      _TipoSegment(
                        rotulo: 'Ajuste',
                        selecionado: _tipo == TipoMovimentacao.ajuste,
                        ativo: ativo && !_carregando,
                        onSelecionado: () =>
                            setState(() => _tipo = TipoMovimentacao.ajuste),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          rotuloQtd,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _qtdController,
                        decoration: InputDecoration(
                          hintText: rotuloQtd,
                          suffixText: sigla,
                        ),
                        keyboardType: fracionavel
                            ? TextInputType.numberWithOptions(decimal: true)
                            : TextInputType.number,
                        enabled: ativo && !_carregando,
                      ),
                    ],
                  ),
                ),
                if (_tipo == TipoMovimentacao.saida) ...[
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Text(
                            'Finalidade',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
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
                          decoration: const InputDecoration(),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          _tipo == TipoMovimentacao.perda
                              ? 'Motivo da perda'
                              : _tipo == TipoMovimentacao.ajuste
                                  ? 'Justificativa'
                                  : 'Observação',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _obsController,
                        decoration: InputDecoration(
                          hintText: _tipo == TipoMovimentacao.perda
                              ? 'Motivo da perda'
                              : _tipo == TipoMovimentacao.ajuste
                                  ? 'Justificativa'
                                  : 'Observação',
                        ),
                        maxLines: 2,
                        enabled: ativo && !_carregando,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Responsável: ${usuario?.nome ?? ''}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    height: 56,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (ativo && !_carregando) ? _registrar : null,
                    child: _carregando
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : const Text('Registrar'),
                  ),
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
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: const Text(
                    'Últimas movimentações',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 9),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: m.delta > 0
                                      ? Theme.of(context).colorScheme.primaryContainer
                                      : Theme.of(context).colorScheme.tertiaryContainer,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    m.delta > 0 ? '+' : '−',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: m.delta > 0
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.tertiary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$tipoLabel$finalidadeLabel',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_formatarDataHora(m.dataHora)} · ${m.usuarioNome ?? ''}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    if (m.observacao != null && m.observacao!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text('Obs: ${m.observacao}'),
                                    ],
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    deltaLabel,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: m.delta > 0
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.tertiary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'saldo ${QuantidadeUtils.format(m.saldoApos, fracionavel: fracionavel)} $sigla',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
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

  Widget _TipoSegment({
    required String rotulo,
    required bool selecionado,
    required bool ativo,
    required VoidCallback onSelecionado,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selecionado,
        child: InkWell(
          onTap: ativo ? onSelecionado : null,
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selecionado && ativo
                  ? colorScheme.surfaceContainerLowest
                  : colorScheme.surface.withValues(alpha: 0),
                  boxShadow: selecionado && ativo
                  ? [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.08),
                        offset: const Offset(0, 1),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
            child: Text(
              rotulo,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selecionado ? FontWeight.w600 : FontWeight.w500,
                color: selecionado && ativo
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
        ),
      ),
    );
  }
}