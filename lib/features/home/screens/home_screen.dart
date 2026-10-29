import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:projeto_2/core/utils/app_exception.dart';
import 'package:projeto_2/features/auth/providers/auth_providers.dart';
import 'package:projeto_2/features/produtos/providers/produto_providers.dart';
import 'package:projeto_2/features/produtos/repositories/catalogo_inicial_repository.dart';
import 'package:projeto_2/features/produtos/widgets/produtos_lista_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _importando = false;

  @override
  Widget build(BuildContext context) {
    final usuarioAsync = ref.watch(sessionProvider);
    final filtro = ref.watch(produtoFiltroProvider);
    final categoriasAsync = ref.watch(categoriasAtivasProvider);

    if (usuarioAsync.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final usuario = usuarioAsync.value;
    final nome = usuario?.nome ?? '';
    final perfil = usuario?.isAdmin == true ? 'Administrador' : 'Operador';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estoque UAN'),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    nome,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    perfil,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            ListTile(
              title: const Text('Todos os produtos'),
              selected: filtro.categoriaId == null,
              onTap: () {
                ref.read(produtoFiltroProvider.notifier).setCategoria(null);
                context.pop();
              },
            ),
            categoriasAsync.when(
              data: (categorias) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Categorias',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  for (final categoria in categorias)
                    ListTile(
                      title: Text(categoria.nome),
                      selected: filtro.categoriaId == categoria.id,
                      onTap: () {
                        ref.read(produtoFiltroProvider.notifier).setCategoria(categoria.id);
                        context.pop();
                      },
                    ),
                ],
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const Divider(),
            ListTile(
              title: const Text('Gerenciar categorias'),
              onTap: () {
                context.pop();
                context.push('/categorias');
              },
            ),
            ListTile(
              title: const Text('Unidades de medida'),
              onTap: () {
                context.pop();
                context.push('/unidades');
              },
            ),
            if (usuario?.isAdmin == true) ...[
              ListTile(
                title: const Text('Importar catálogo inicial'),
                onTap: _importando ? null : () {
                  context.pop();
                  _importarCatalogo(context);
                },
              ),
            ],
            const Divider(),
            ListTile(
              title: const Text('Sair'),
              onTap: () {
                context.pop();
                ref.read(sessionProvider.notifier).sair();
              },
            ),
          ],
        ),
      ),
      body: const ProdutosListaView(mostrarCategorias: false),
      floatingActionButton: _importando
          ? const FloatingActionButton.extended(
              onPressed: null,
              icon: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              label: Text('Importando...'),
            )
          : FloatingActionButton.extended(
              onPressed: () => context.push('/produtos/novo'),
              icon: const Icon(Icons.add),
              label: const Text('Novo produto'),
            ),
    );
  }

  Future<void> _importarCatalogo(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Importar catálogo inicial'),
        content: const Text(
          'Cadastrar os 91 produtos das notas fiscais? '
          'Produtos que já existirem serão ignorados. '
          'O saldo de todos começa em 0.',
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => context.pop(true),
            child: const Text('Importar'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirmado != true) return;

    setState(() => _importando = true);

    try {
      final usuario = ref.read(sessionProvider).value;
      if (usuario == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuário não encontrado.')),
        );
        return;
      }

      final resultado = await ref
          .read(catalogoInicialRepositoryProvider)
          .importar(usuario.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${resultado.criados} produtos cadastrados, '
            '${resultado.ignorados} já existiam.',
          ),
        ),
      );

      ref.invalidate(produtosProvider);
      ref.invalidate(categoriasAtivasProvider);
      ref.invalidate(categoriasTodasProvider);
      ref.invalidate(unidadesAtivasProvider);
      ref.invalidate(unidadesTodasProvider);
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
        setState(() => _importando = false);
      }
    }
  }
}
