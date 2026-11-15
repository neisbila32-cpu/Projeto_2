import 'package:flutter/material.dart';
import 'package:projeto_2/features/home/widgets/app_drawer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:projeto_2/core/utils/app_exception.dart';
import 'package:projeto_2/features/produtos/models/unidade.dart';
import 'package:projeto_2/features/produtos/providers/produto_providers.dart';

class UnidadesScreen extends ConsumerStatefulWidget {
  const UnidadesScreen({super.key});

  @override
  ConsumerState<UnidadesScreen> createState() => _UnidadesScreenState();
}

class _UnidadesScreenState extends ConsumerState<UnidadesScreen> {
  Future<void> _novaUnidade() async {
    var sigla = '';
    var nome = '';
    bool fracionavel = false;

    final resultado = await showDialog<
      ({String sigla, String nome, bool fracionavel})
    >(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Nova unidade'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Sigla'),
                autofocus: true,
                textCapitalization: TextCapitalization.none,
                onChanged: (valor) => sigla = valor,
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(labelText: 'Nome'),
                onChanged: (valor) => nome = valor,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Aceita decimais (kg, L...)'),
                value: fracionavel,
                onChanged: (valor) {
                  setDialogState(() => fracionavel = valor);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop((
                sigla: sigla,
                nome: nome,
                fracionavel: fracionavel,
              )),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (resultado == null) return;

    try {
      await ref
          .read(unidadeRepositoryProvider)
          .criar(
            sigla: resultado.sigla,
            nome: resultado.nome,
            fracionavel: resultado.fracionavel,
          );
      if (!mounted) return;
      ref.invalidate(unidadesTodasProvider);
      ref.invalidate(unidadesAtivasProvider);
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro inesperado. Tente novamente.')),
      );
    }
  }

  Future<void> _excluir(Unidade unidade) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir unidade?'),
        content: Text(
          'A unidade ${unidade.rotulo} será excluída permanentemente. '
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (!mounted || confirmado != true) return;
    try {
      await ref.read(unidadeRepositoryProvider).excluir(unidade.id);
      if (!mounted) return;
      ref.invalidate(unidadesTodasProvider);
      ref.invalidate(unidadesAtivasProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unidade excluída.')),
      );
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
    }
  }

  Future<void> _definirAtiva(Unidade unidade, bool ativa) async {
    try {
      await ref.read(unidadeRepositoryProvider).definirAtiva(unidade.id, ativa);
      if (!mounted) return;
      ref.invalidate(unidadesTodasProvider);
      ref.invalidate(unidadesAtivasProvider);
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro inesperado. Tente novamente.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unidadesAsync = ref.watch(unidadesTodasProvider);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: drawerMenuButton(context),
        title: const Text('Unidades de medida'),
      ),
      body: unidadesAsync.when(
        data: (unidades) {
          if (unidades.isEmpty) {
            return const Center(child: Text('Nenhuma unidade cadastrada.'));
          }
          return ListView.builder(
            itemCount: unidades.length,
            itemBuilder: (context, index) {
              final unidade = unidades[index];
              return ListTile(
                title: Text(
                  '${unidade.nome} (${unidade.sigla})${unidade.ativa ? '' : ' - Inativa'}',
                  style: TextStyle(color: unidade.ativa ? null : Colors.grey),
                ),
                subtitle: Text(
                  unidade.fracionavel
                      ? 'Fracion\u00e1vel (aceita decimais)'
                      : 'Cont\u00e1vel (apenas inteiros)',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (valor) async {
                    if (valor == 'ativar') {
                      await _definirAtiva(unidade, true);
                    } else if (valor == 'inativar') {
                      await _definirAtiva(unidade, false);
                    } else if (valor == 'excluir') {
                      await _excluir(unidade);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: unidade.ativa ? 'inativar' : 'ativar',
                      child: Text(unidade.ativa ? 'Inativar' : 'Reativar'),
                    ),
                    const PopupMenuItem(
                      value: 'excluir',
                      child: Text('Excluir'),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text('Erro ao carregar unidades.')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _novaUnidade,
        child: const Icon(Icons.add),
      ),
    );
  }
}
