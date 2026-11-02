import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:projeto_2/core/utils/app_exception.dart';
import 'package:projeto_2/features/produtos/models/categoria.dart';
import 'package:projeto_2/features/produtos/providers/produto_providers.dart';

class CategoriasScreen extends ConsumerStatefulWidget {
  const CategoriasScreen({super.key});

  @override
  ConsumerState<CategoriasScreen> createState() => _CategoriasScreenState();
}

class _CategoriasScreenState extends ConsumerState<CategoriasScreen> {
  Future<void> _novaCategoria() async {
    final controller = TextEditingController();
    final resultado = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nova categoria'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nome'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (!mounted) return;
    if (resultado == null || resultado.isEmpty) return;

    try {
      await ref.read(categoriaRepositoryProvider).criar(resultado);
      if (!mounted) return;
      ref.invalidate(categoriasTodasProvider);
      ref.invalidate(categoriasAtivasProvider);
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

  Future<void> _renomear(Categoria categoria) async {
    final controller = TextEditingController(text: categoria.nome);
    final resultado = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Renomear categoria'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nome'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (!mounted) return;
    if (resultado == null || resultado.isEmpty) return;

    try {
      await ref
          .read(categoriaRepositoryProvider)
          .renomear(categoria.id, resultado);
      if (!mounted) return;
      ref.invalidate(categoriasTodasProvider);
      ref.invalidate(categoriasAtivasProvider);
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

  Future<void> _definirAtiva(Categoria categoria, bool ativa) async {
    try {
      await ref
          .read(categoriaRepositoryProvider)
          .definirAtiva(categoria.id, ativa);
      if (!mounted) return;
      ref.invalidate(categoriasTodasProvider);
      ref.invalidate(categoriasAtivasProvider);
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

  Future<void> _excluir(Categoria categoria) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir categoria'),
        content: Text('Deseja excluir a categoria "${categoria.nome}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (!mounted || confirmado != true) return;
    try {
      await ref.read(categoriaRepositoryProvider).excluir(categoria.id);
      if (!mounted) return;
      ref.invalidate(categoriasTodasProvider);
      ref.invalidate(categoriasAtivasProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Categoria excluída com sucesso.')),
      );
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro inesperado ao excluir categoria.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriasAsync = ref.watch(categoriasTodasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categorias')),
      body: categoriasAsync.when(
        data: (categorias) {
          if (categorias.isEmpty) {
            return const Center(child: Text('Nenhuma categoria cadastrada.'));
          }
          return ListView.builder(
            itemCount: categorias.length,
            itemBuilder: (context, index) {
              final categoria = categorias[index];
              return ListTile(
                title: Text(
                  categoria.nome,
                  style: TextStyle(color: categoria.ativa ? null : Colors.grey),
                ),
                subtitle: categoria.ativa ? null : const Text('Inativa'),
                trailing: PopupMenuButton<String>(
                  onSelected: (valor) async {
                    if (valor == 'renomear') {
                      await _renomear(categoria);
                    } else if (valor == 'ativar') {
                      await _definirAtiva(categoria, true);
                    } else if (valor == 'inativar') {
                      await _definirAtiva(categoria, false);
                    } else if (valor == 'excluir') {
                      await _excluir(categoria);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'renomear',
                      child: const Text('Renomear'),
                    ),
                    PopupMenuItem(
                      value: categoria.ativa ? 'inativar' : 'ativar',
                      child: Text(categoria.ativa ? 'Inativar' : 'Reativar'),
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
            const Center(child: Text('Erro ao carregar categorias.')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _novaCategoria,
        child: const Icon(Icons.add),
      ),
    );
  }
}
