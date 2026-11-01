import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:projeto_2/core/utils/app_exception.dart';
import 'package:projeto_2/features/auth/providers/auth_providers.dart';
import 'package:projeto_2/features/historico/providers/historico_providers.dart';
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
        title: const Text(
          'Estoque UAN',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: nome.isNotEmpty
                  ? Text(
                      nome[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                60 + MediaQuery.of(context).padding.top,
                24,
                14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: nome.isNotEmpty
                        ? Text(
                            nome[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    nome,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      perfil,
                      style: const TextStyle(
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ItemMenu(
              titulo: 'Todos os produtos',
              selected: filtro.categoriaId == null,
              onTap: () {
                ref.read(produtoFiltroProvider.notifier).setCategoria(null);
                context.pop();
              },
            ),
            _ItemMenu(
              titulo: 'Histórico',
              selected: false,
              onTap: () {
                ref.read(historicoFiltroProvider.notifier).limpar();
                context.pop();
                context.push('/historico');
              },
            ),
            _ItemMenu(
              titulo: 'Painel',
              selected: false,
              onTap: () {
                context.pop();
                context.push('/painel');
              },
            ),
            categoriasAsync.when(
              data: (categorias) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 16, 0, 6),
                    child: Text(
                      'Categorias'.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.7,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  for (final categoria in categorias)
                    _ItemCategoria(
                      nome: categoria.nome,
                      selected: filtro.categoriaId == categoria.id,
                      onTap: () {
                        ref.read(produtoFiltroProvider.notifier)
                            .setCategoria(categoria.id);
                        context.pop();
                      },
                    ),
                ],
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Divider(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            _ItemCategoria(
              nome: 'Gerenciar categorias',
              selected: false,
              altura: 40,
              comBolinha: false,
              onTap: () {
                context.pop();
                context.push('/categorias');
              },
            ),
            _ItemCategoria(
              nome: 'Unidades de medida',
              selected: false,
              altura: 40,
              comBolinha: false,
              onTap: () {
                context.pop();
                context.push('/unidades');
              },
            ),
            if (usuario?.isAdmin == true) ...[
              _ItemCategoria(
                nome: 'Importar catálogo inicial',
                selected: false,
                altura: 40,
                comBolinha: false,
                onTap: _importando ? null : () {
                  context.pop();
                  _importarCatalogo(context);
                },
              ),
              _ItemCategoria(
                nome: 'Backup e restauração',
                selected: false,
                altura: 40,
                comBolinha: false,
                onTap: () {
                  context.pop();
                  context.push('/backup');
                },
              ),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Divider(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            _ItemCategoria(
              nome: 'Sair',
              selected: false,
              altura: 40,
              comBolinha: false,
              onTap: () {
                context.pop();
                ref.read(sessionProvider.notifier).sair();
              },
            ),
          ],
        ),
      ),      body: const ProdutosListaView(mostrarCategorias: false),
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


class _ItemMenu extends StatelessWidget {
  const _ItemMenu({
    required this.titulo,
    required this.selected,
    required this.onTap,
  });

  final String titulo;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 46,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: selected ? colorScheme.primaryContainer : null,
        borderRadius: BorderRadius.circular(23),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(23),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: Text(
              titulo,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? colorScheme.onPrimaryContainer : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemCategoria extends StatelessWidget {
  const _ItemCategoria({
    required this.nome,
    required this.selected,
    required this.onTap,
    this.altura = 34,
    this.comBolinha = true,
  });

  final String nome;
  final bool selected;
  final VoidCallback? onTap;
  final double altura;
  final bool comBolinha;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: altura,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: selected
          ? BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(17),
            )
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              if (comBolinha) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: selected
                        ? colorScheme.primary
                        : colorScheme.primary.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  nome,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}