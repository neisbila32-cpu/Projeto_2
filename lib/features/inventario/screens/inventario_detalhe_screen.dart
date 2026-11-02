import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:projeto_2/core/utils/app_exception.dart';
import 'package:projeto_2/core/utils/quantidade_utils.dart';
import 'package:projeto_2/features/auth/providers/auth_providers.dart';
import 'package:projeto_2/features/historico/providers/historico_providers.dart';
import 'package:projeto_2/features/inventario/models/formato_inventario.dart';
import 'package:projeto_2/features/inventario/models/inventario.dart';
import 'package:projeto_2/features/inventario/providers/inventario_providers.dart';
import 'package:projeto_2/features/movimentacoes/providers/movimentacao_providers.dart';
import 'package:projeto_2/features/painel/providers/painel_providers.dart';
import 'package:projeto_2/features/produtos/models/produto.dart';
import 'package:projeto_2/features/produtos/providers/produto_providers.dart';
import 'package:projeto_2/features/produtos/widgets/produtos_lista_view.dart';

class InventarioDetalheScreen extends ConsumerStatefulWidget {
  const InventarioDetalheScreen({super.key, required this.inventarioId});

  final int inventarioId;

  @override
  ConsumerState<InventarioDetalheScreen> createState() =>
      _InventarioDetalheScreenState();
}

class _InventarioDetalheScreenState
    extends ConsumerState<InventarioDetalheScreen> {
  bool _finalizando = false;

  void _invalidarInventario() {
    ref.invalidate(inventarioEmAndamentoProvider);
    ref.invalidate(inventariosProvider);
    ref.invalidate(inventarioPorIdProvider(widget.inventarioId));
    ref.invalidate(itensInventarioProvider(widget.inventarioId));
    ref.invalidate(auditoriaInventarioProvider(widget.inventarioId));
  }

  void _invalidarEstoque() {
    ref.invalidate(produtosProvider);
    ref.invalidate(produtoPorIdProvider);
    ref.invalidate(produtoTemMovimentacoesProvider);
    ref.invalidate(ultimasMovimentacoesProvider);
    ref.invalidate(historicoProvider);
    ref.invalidate(painelProvider);
  }

  ItemInventario? _itemDoProduto(List<ItemInventario>? itens, int produtoId) {
    if (itens == null) return null;
    for (final it in itens) {
      if (it.produtoId == produtoId) return it;
    }
    return null;
  }

  Future<void> _aviso(String titulo, String mensagem) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirContagem(Produto produto) async {
    if (!produto.ativo) {
      await _aviso('Produto inativo', 'Produto inativo não pode ser contado.');
      return;
    }
    final itens = ref.read(itensInventarioProvider(widget.inventarioId)).value;
    final atual = _itemDoProduto(itens, produto.id);
    final salvou = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoContagem(
        inventarioId: widget.inventarioId,
        produto: produto,
        itemAtual: atual,
      ),
    );
    if (salvou == true && mounted) {
      _invalidarInventario();
    }
  }

  Future<void> _recontar(ItemInventario it) async {
    final p = await ref
        .read(produtoRepositoryProvider)
        .buscarPorId(it.produtoId);
    if (!mounted || p == null) return;
    await _abrirContagem(p);
  }

  Future<void> _escolherProduto() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, _) {
                        final n =
                            ref
                                .watch(
                                  itensInventarioProvider(widget.inventarioId),
                                )
                                .value
                                ?.length ??
                            0;
                        return Text(
                          'Escolha o produto · $n contados',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Concluir'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ProdutosListaView(
                aoTocar: (p) {
                  _abrirContagem(p);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _remover(ItemInventario it) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover contagem?'),
        content: Text(
          'A contagem de "${it.produtoNome}" será removida deste inventário.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(inventarioRepositoryProvider).removerItem(it.id);
      if (!mounted) return;
      _invalidarInventario();
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _finalizar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar inventário?'),
        content: const Text(
          'Os ajustes de estoque serão lançados com a justificativa de cada '
          'divergência, e o saldo de cada produto contado passará a ser igual '
          'à quantidade contada. Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    final usuario = ref.read(sessionProvider).value;
    if (usuario == null) return;
    setState(() => _finalizando = true);
    try {
      final r = await ref
          .read(inventarioRepositoryProvider)
          .finalizar(inventarioId: widget.inventarioId, usuarioId: usuario.id);
      _invalidarInventario();
      _invalidarEstoque();
      if (!mounted) return;
      await _aviso(
        'Inventário finalizado',
        '${r.ajustados} ajustes lançados e ${r.semDivergencia} produtos sem divergência.',
      );
      if (!mounted) return;
      context.pop();
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _finalizando = false);
    }
  }

  BoxDecoration _decoracao(ColorScheme cs) => BoxDecoration(
    color: cs.surfaceContainerLowest,
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(
        color: cs.shadow.withValues(alpha: 0.06),
        offset: const Offset(0, 1),
        blurRadius: 2,
      ),
    ],
  );

  Widget _pilula(String texto, Color fundo, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cor),
      ),
    );
  }

  Widget _cabecalho(ColorScheme cs, Inventario inv) {
    final responsavel = inv.usuarioNome ?? '-';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _decoracao(cs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              inv.emAndamento
                  ? _pilula(
                      'Em andamento',
                      cs.primaryContainer,
                      cs.onPrimaryContainer,
                    )
                  : _pilula(
                      'Finalizado',
                      cs.surfaceContainerHigh,
                      cs.onSurfaceVariant,
                    ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  FormatoInventario.dataHora(inv.dataHora),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Responsável: $responsavel',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          if (inv.observacao != null) ...[
            const SizedBox(height: 2),
            Text(
              inv.observacao!,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${inv.totalItens} produtos contados, ${inv.totalDivergentes} com divergência',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          if (inv.emAndamento && inv.totalItens > 0) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: _finalizando ? null : _finalizar,
                child: _finalizando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Finalizar inventário'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _linhaItem(ColorScheme cs, ItemInventario it, bool editavel) {
    final div = it.divergencia;
    final sinal = div > 0 ? '+' : '-';
    final textoDiv = div == 0
        ? 'OK'
        : '$sinal${QuantidadeUtils.format(div.abs(), fracionavel: it.fracionavel)} ${it.unidadeSigla}';
    final fundo = div > 0
        ? cs.primaryContainer
        : div < 0
        ? cs.tertiaryContainer
        : cs.surfaceContainerHigh;
    final cor = div > 0
        ? cs.onPrimaryContainer
        : div < 0
        ? cs.onTertiaryContainer
        : cs.onSurfaceVariant;
    final sistema = QuantidadeUtils.format(
      it.qtdSistema,
      fracionavel: it.fracionavel,
    );
    final contado = QuantidadeUtils.format(
      it.qtdContada,
      fracionavel: it.fracionavel,
    );

    return InkWell(
      onTap: editavel && !_finalizando ? () => _recontar(it) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    it.produtoNome,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Sistema: $sistema ${it.unidadeSigla} · Contado: $contado ${it.unidadeSigla}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  if (it.justificativa != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Justificativa: ${it.justificativa}',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (it.ajustado)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Ajustado',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _pilula(textoDiv, fundo, cor),
            if (editavel)
              IconButton(
                tooltip: 'Remover contagem',
                icon: Icon(Icons.delete_outline, color: cs.onSurfaceVariant),
                onPressed: _finalizando ? null : () => _remover(it),
              )
            else
              const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  Widget _itens(ColorScheme cs, List<ItemInventario> itens, bool editavel) {
    if (itens.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nenhum produto contado ainda.',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            if (editavel)
              Text(
                'Toque em "Contar produto" para começar.',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
          ],
        ),
      );
    }
    return Container(
      decoration: _decoracao(cs),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < itens.length; i++) ...[
            _linhaItem(cs, itens[i], editavel),
            if (i < itens.length - 1)
              Divider(
                height: 1,
                indent: 20,
                endIndent: 20,
                color: cs.outlineVariant,
              ),
          ],
        ],
      ),
    );
  }

  Widget _valorAuditoria(String rotulo, String valor, ColorScheme cs) {
    return SizedBox(
      width: 145,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rotulo,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(valor, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _cartaoAuditoria(ColorScheme cs, AuditoriaItemInventario item) {
    final delta = item.delta;
    final temAjuste = item.temAjusteVinculado && delta != null;
    final positivo = temAjuste && delta > 0;
    final negativo = temAjuste && delta < 0;
    final divergenciaFormatada = item.divergencia == 0
        ? 'Sem divergência'
        : '${item.divergencia > 0 ? '+' : ''}'
              '${QuantidadeUtils.format(item.divergencia, fracionavel: item.fracionavel)} ${item.unidadeSigla}';
    final deltaFormatado = delta == null
        ? null
        : '${delta > 0 ? '+' : ''}'
              '${QuantidadeUtils.format(delta, fracionavel: item.fracionavel)} ${item.unidadeSigla}';

    final status = positivo
        ? 'Ajuste positivo'
        : negativo
        ? 'Ajuste negativo'
        : item.divergencia == 0
        ? 'Sem ajuste necessário'
        : 'Sem ajuste vinculado';
    final fundoStatus = positivo
        ? cs.primaryContainer
        : negativo
        ? cs.tertiaryContainer
        : item.divergencia == 0
        ? cs.surfaceContainerHigh
        : cs.errorContainer;
    final corStatus = positivo
        ? cs.onPrimaryContainer
        : negativo
        ? cs.onTertiaryContainer
        : item.divergencia == 0
        ? cs.onSurfaceVariant
        : cs.onErrorContainer;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.produtoNome,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _pilula(status, fundoStatus, corStatus),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _valorAuditoria(
                  'Saldo do sistema na contagem',
                  '${QuantidadeUtils.format(item.qtdSistema, fracionavel: item.fracionavel)} ${item.unidadeSigla}',
                  cs,
                ),
                _valorAuditoria(
                  'Quantidade contada',
                  '${QuantidadeUtils.format(item.qtdContada, fracionavel: item.fracionavel)} ${item.unidadeSigla}',
                  cs,
                ),
                _valorAuditoria('Divergência', divergenciaFormatada, cs),
              ],
            ),
            if (temAjuste) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _valorAuditoria(
                    'Saldo antes do ajuste',
                    '${QuantidadeUtils.format(item.saldoAntesAjuste!, fracionavel: item.fracionavel)} ${item.unidadeSigla}',
                    cs,
                  ),
                  _valorAuditoria('Delta aplicado', deltaFormatado!, cs),
                  _valorAuditoria(
                    'Saldo após o ajuste',
                    '${QuantidadeUtils.format(item.saldoApos!, fracionavel: item.fracionavel)} ${item.unidadeSigla}',
                    cs,
                  ),
                ],
              ),
              if (item.justificativaAjuste != null &&
                  item.justificativaAjuste!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Justificativa: ${item.justificativaAjuste}'),
              ],
              if (item.dataHoraAjuste != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Registrado em ${FormatoInventario.dataHora(item.dataHoraAjuste!)}'
                  '${item.usuarioAjusteNome == null ? '' : ' · Responsável: ${item.usuarioAjusteNome}'}',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ] else if (item.divergencia == 0) ...[
              const SizedBox(height: 10),
              Text(
                'A quantidade contada coincide com o saldo do sistema. Nenhum ajuste foi necessário.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Text(
                'Há divergência na contagem, mas não foi encontrado um movimento de ajuste vinculado a este inventário.',
                style: TextStyle(color: corStatus),
              ),
              if (item.justificativaContagem != null &&
                  item.justificativaContagem!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Justificativa da contagem: ${item.justificativaContagem}',
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _auditoria(ColorScheme cs) {
    final auditoria = ref.watch(
      auditoriaInventarioProvider(widget.inventarioId),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            'Auditoria dos ajustes',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        auditoria.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Não foi possível carregar a auditoria do inventário.',
              ),
              TextButton(
                onPressed: () => ref.invalidate(
                  auditoriaInventarioProvider(widget.inventarioId),
                ),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
          data: (itens) {
            if (itens.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Este inventário não possui itens registrados.'),
              );
            }
            return Column(
              children: [for (final item in itens) _cartaoAuditoria(cs, item)],
            );
          },
        ),
      ],
    );
  }

  Widget _conteudoItens(ColorScheme cs, Inventario inventario) {
    if (!inventario.emAndamento) return _auditoria(cs);

    final itens = ref.watch(itensInventarioProvider(widget.inventarioId));
    return itens.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const Text('Erro ao carregar os itens.'),
      data: (lista) => _itens(cs, lista, true),
    );
  }

  Widget _erro() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Erro ao carregar o inventário.'),
          TextButton(
            onPressed: _invalidarInventario,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final invAsync = ref.watch(inventarioPorIdProvider(widget.inventarioId));
    final emAndamento = invAsync.value?.emAndamento ?? false;

    return Scaffold(
      appBar: AppBar(title: Text('Inventário nº ${widget.inventarioId}')),
      floatingActionButton: emAndamento
          ? FloatingActionButton.extended(
              onPressed: _finalizando ? null : _escolherProduto,
              icon: const Icon(Icons.add),
              label: const Text('Contar produto'),
            )
          : null,
      body: invAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _erro(),
        data: (inv) {
          if (inv == null) {
            return const Center(child: Text('Inventário não encontrado.'));
          }
          return RefreshIndicator(
            onRefresh: () async => _invalidarInventario(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                _cabecalho(cs, inv),
                const SizedBox(height: 20),
                _conteudoItens(cs, inv),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Rotulo extends StatelessWidget {
  const _Rotulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 6),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _DialogoContagem extends ConsumerStatefulWidget {
  const _DialogoContagem({
    required this.inventarioId,
    required this.produto,
    required this.itemAtual,
  });

  final int inventarioId;
  final Produto produto;
  final ItemInventario? itemAtual;

  @override
  ConsumerState<_DialogoContagem> createState() => _DialogoContagemState();
}

class _DialogoContagemState extends ConsumerState<_DialogoContagem> {
  final _qtd = TextEditingController();
  final _just = TextEditingController();
  String? _erro;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final atual = widget.itemAtual;
    if (atual != null) {
      _qtd.text = QuantidadeUtils.format(
        atual.qtdContada,
        fracionavel: widget.produto.unidadeFracionavel,
      );
      _just.text = atual.justificativa ?? '';
    }
  }

  @override
  void dispose() {
    _qtd.dispose();
    _just.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final p = widget.produto;
    final contada = QuantidadeUtils.parse(
      _qtd.text,
      fracionavel: p.unidadeFracionavel,
    );
    if (contada == null) {
      setState(() {
        _erro = p.unidadeFracionavel
            ? 'Informe uma quantidade válida (até 3 casas decimais).'
            : 'Informe uma quantidade inteira.';
      });
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await ref
          .read(inventarioRepositoryProvider)
          .registrarContagem(
            inventarioId: widget.inventarioId,
            produtoId: p.id,
            qtdContada: contada,
            justificativa: _just.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _salvando = false;
        _erro = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = widget.produto;
    final contada = QuantidadeUtils.parse(
      _qtd.text,
      fracionavel: p.unidadeFracionavel,
    );
    final divergencia = contada == null ? null : contada - p.saldo;

    String? textoDiv;
    Color corDiv = cs.onSurfaceVariant;
    if (divergencia != null) {
      if (divergencia == 0) {
        textoDiv = 'Sem divergência';
      } else {
        final sinal = divergencia > 0 ? '+' : '-';
        final valor = QuantidadeUtils.format(
          divergencia.abs(),
          fracionavel: p.unidadeFracionavel,
        );
        textoDiv = 'Divergência: $sinal$valor ${p.unidadeSigla}';
        corDiv = divergencia > 0 ? cs.primary : cs.tertiary;
      }
    }

    return AlertDialog(
      title: Text(p.nome, maxLines: 2, overflow: TextOverflow.ellipsis),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saldo no app: ${p.saldoFormatado}',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            const _Rotulo('Quantidade contada'),
            TextField(
              controller: _qtd,
              autofocus: true,
              keyboardType: TextInputType.numberWithOptions(
                decimal: p.unidadeFracionavel,
              ),
              decoration: InputDecoration(
                hintText: '0',
                suffixText: p.unidadeSigla,
              ),
              onChanged: (_) => setState(() => _erro = null),
            ),
            if (textoDiv != null) ...[
              const SizedBox(height: 10),
              Text(
                textoDiv,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: corDiv,
                ),
              ),
            ],
            if (divergencia != null && divergencia != 0) ...[
              const SizedBox(height: 14),
              const _Rotulo('Justificativa da divergência'),
              TextField(
                controller: _just,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Por que a contagem difere do saldo?',
                ),
                onChanged: (_) => setState(() => _erro = null),
              ),
            ],
            if (_erro != null) ...[
              const SizedBox(height: 10),
              Text(_erro!, style: TextStyle(fontSize: 13, color: cs.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _salvando ? null : _salvar,
          child: _salvando
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.onPrimary,
                  ),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
