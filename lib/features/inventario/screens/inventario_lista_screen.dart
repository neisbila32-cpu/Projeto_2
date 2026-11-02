import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:projeto_2/core/utils/app_exception.dart';
import 'package:projeto_2/features/auth/providers/auth_providers.dart';
import 'package:projeto_2/features/inventario/models/formato_inventario.dart';
import 'package:projeto_2/features/inventario/models/inventario.dart';
import 'package:projeto_2/features/inventario/providers/inventario_providers.dart';

class InventarioListaScreen extends ConsumerStatefulWidget {
  const InventarioListaScreen({super.key});

  @override
  ConsumerState<InventarioListaScreen> createState() =>
      _InventarioListaScreenState();
}

class _InventarioListaScreenState extends ConsumerState<InventarioListaScreen> {
  bool _iniciando = false;

  void _atualizar() {
    ref.invalidate(inventarioEmAndamentoProvider);
    ref.invalidate(inventariosProvider);
  }

  Future<void> _iniciar() async {
    final observacao = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogoIniciar(),
    );
    if (observacao == null || !mounted) return;
    final usuario = ref.read(sessionProvider).value;
    if (usuario == null) return;
    setState(() => _iniciando = true);
    try {
      final id = await ref
          .read(inventarioRepositoryProvider)
          .iniciar(usuarioId: usuario.id, observacao: observacao);
      _atualizar();
      if (!mounted) return;
      await context.push('/inventarios/$id');
      if (!mounted) return;
      _atualizar();
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _iniciando = false);
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

  Widget _cartaoIniciar(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _decoracao(cs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nenhum inventário em andamento',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Conte os produtos, compare com o saldo do app e, ao finalizar, '
            'os ajustes são lançados com a justificativa de cada divergência.',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _iniciando ? null : _iniciar,
              child: _iniciando
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onPrimary,
                      ),
                    )
                  : const Text('Iniciar inventário'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cartaoAndamento(ColorScheme cs, Inventario inv) {
    final responsavel = inv.usuarioNome ?? '-';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _decoracao(cs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pilula('Em andamento', cs.primaryContainer, cs.onPrimaryContainer),
          const SizedBox(height: 12),
          Text(
            'Iniciado em ${FormatoInventario.dataHora(inv.dataHora)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Responsável: $responsavel',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          if (inv.observacao != null) ...[
            const SizedBox(height: 4),
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
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () async {
                await context.push('/inventarios/${inv.id}');
                if (!mounted) return;
                _atualizar();
              },
              child: const Text('Continuar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _anteriores(ColorScheme cs, List<Inventario> todos) {
    final finalizados = todos.where((i) => !i.emAndamento).toList();
    if (finalizados.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(
          'Nenhum inventário finalizado ainda.',
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        ),
      );
    }
    return Container(
      decoration: _decoracao(cs),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < finalizados.length; i++) ...[
            _linhaAnterior(cs, finalizados[i]),
            if (i < finalizados.length - 1)
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

  Widget _linhaAnterior(ColorScheme cs, Inventario inv) {
    final responsavel = inv.usuarioNome ?? '-';
    final semDivergencia = inv.totalDivergentes == 0;
    return InkWell(
      onTap: () => context.push('/inventarios/${inv.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inventário nº ${inv.id} · ${FormatoInventario.data(inv.dataHora)}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Responsável: $responsavel · ${inv.totalItens} produtos',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  if (inv.observacao != null)
                    Text(
                      inv.observacao!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            semDivergencia
                ? _pilula('Sem divergências', cs.surfaceContainerHigh,
                    cs.onSurfaceVariant)
                : _pilula(
                    inv.totalDivergentes == 1
                        ? '1 divergência'
                        : '${inv.totalDivergentes} divergências',
                    cs.tertiaryContainer,
                    cs.onTertiaryContainer,
                  ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final emAndamento = ref.watch(inventarioEmAndamentoProvider);
    final lista = ref.watch(inventariosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Inventário físico')),
      body: RefreshIndicator(
        onRefresh: () async => _atualizar(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            emAndamento.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Column(
                children: [
                  const Text('Erro ao carregar o inventário.'),
                  TextButton(
                    onPressed: _atualizar,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
              data: (inv) =>
                  inv == null ? _cartaoIniciar(cs) : _cartaoAndamento(cs, inv),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 28, 12, 10),
              child: Text(
                'Inventários anteriores',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            lista.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => const Text('Erro ao carregar a lista.'),
              data: (todos) => _anteriores(cs, todos),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogoIniciar extends StatefulWidget {
  const _DialogoIniciar();

  @override
  State<_DialogoIniciar> createState() => _DialogoIniciarState();
}

class _DialogoIniciarState extends State<_DialogoIniciar> {
  final _obs = TextEditingController();

  @override
  void dispose() {
    _obs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Iniciar inventário'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Observação (opcional)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _obs,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Por exemplo, setor ou categoria contada',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_obs.text.trim()),
          child: const Text('Iniciar'),
        ),
      ],
    );
  }
}