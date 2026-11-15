import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:projeto_2/core/theme/categoria_cores.dart';
import 'package:projeto_2/core/utils/app_exception.dart';
import 'package:projeto_2/features/auth/providers/auth_providers.dart';
import 'package:projeto_2/features/historico/providers/historico_providers.dart';
import 'package:projeto_2/features/produtos/providers/produto_providers.dart';
import 'package:projeto_2/features/produtos/repositories/catalogo_inicial_repository.dart';

/// Drawer compartilhado pelas telas principais do aplicativo.
class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  bool _importando = false;

  void _navegar(BuildContext context, String destino) {
    final router = GoRouter.of(context);
    final atual = GoRouterState.of(context).matchedLocation;
    final podeVoltar = router.canPop();
    Scaffold.of(context).closeDrawer();
    if (atual == destino) return;

    if (destino == '/home') {
      if (podeVoltar) {
        router.pop();
      } else {
        router.go('/home');
      }
      return;
    }

    if (atual == '/home') {
      router.push(destino);
    } else if (podeVoltar) {
      router.pushReplacement(destino);
    } else {
      router.go(destino);
    }
  }

  Future<void> _importarCatalogo() async {
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
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Importar'),
          ),
        ],
      ),
    );
    if (!mounted || confirmado != true) return;

    setState(() => _importando = true);
    try {
      final usuario = ref.read(sessionProvider).value;
      if (usuario == null) {
        throw const AppException('Usuário não encontrado.');
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro inesperado. Tente novamente.')),
      );
    } finally {
      if (mounted) setState(() => _importando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(sessionProvider).value;
    final filtro = ref.watch(produtoFiltroProvider);
    final categorias = ref.watch(categoriasAtivasProvider);
    final atual = GoRouterState.of(context).matchedLocation;
    final nome = usuario?.nome ?? '';

    return Drawer(
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
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: nome.isEmpty
                      ? null
                      : Text(
                          nome[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    usuario?.isAdmin == true ? 'Administrador' : 'Operador',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ItemMenu(
            titulo: 'Todos os produtos',
            selected: atual == '/home' && filtro.categoriaId == null,
            onTap: () {
              ref.read(produtoFiltroProvider.notifier).setCategoria(null);
              _navegar(context, '/home');
            },
          ),
          _ItemMenu(
            titulo: 'Histórico',
            selected: atual == '/historico',
            onTap: () {
              ref.read(historicoFiltroProvider.notifier).limpar();
              _navegar(context, '/historico');
            },
          ),
          _ItemMenu(
            titulo: 'Painel',
            selected: atual == '/painel',
            onTap: () => _navegar(context, '/painel'),
          ),
          _ItemMenu(
            titulo: 'Relatórios',
            selected: atual == '/relatorios',
            onTap: () => _navegar(context, '/relatorios'),
          ),
          _ItemMenu(
            titulo: 'Inventário físico',
            selected: atual == '/inventarios',
            onTap: () => _navegar(context, '/inventarios'),
          ),
          _ItemMenu(
            titulo: 'Meu perfil',
            selected: atual == '/perfil',
            onTap: () => _navegar(context, '/perfil'),
          ),
          _ItemMenu(
            titulo: 'Configurações',
            selected: atual == '/configuracoes',
            onTap: () => _navegar(context, '/configuracoes'),
          ),
          _ItemMenu(
            titulo: 'Como usar',
            selected: atual == '/tutorial',
            onTap: () => _navegar(context, '/tutorial'),
          ),
          categorias.when(
            data: (lista) => Column(
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
                for (final categoria in lista)
                  _ItemCategoria(
                    nome: categoria.nome,
                    selected:
                        atual == '/home' && filtro.categoriaId == categoria.id,
                    onTap: () {
                      ref
                          .read(produtoFiltroProvider.notifier)
                          .setCategoria(categoria.id);
                      _navegar(context, '/home');
                    },
                  ),
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Divider(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          _ItemCategoria(
            nome: 'Gerenciar categorias',
            selected: atual == '/categorias',
            altura: 40,
            comBolinha: false,
            onTap: () => _navegar(context, '/categorias'),
          ),
          _ItemCategoria(
            nome: 'Unidades de medida',
            selected: atual == '/unidades',
            altura: 40,
            comBolinha: false,
            onTap: () => _navegar(context, '/unidades'),
          ),
          if (usuario?.isAdmin == true) ...[
            _ItemCategoria(
              nome: 'Importar catálogo inicial',
              selected: false,
              altura: 40,
              comBolinha: false,
              onTap: _importando
                  ? null
                  : () {
                      Scaffold.of(context).closeDrawer();
                      _importarCatalogo();
                    },
            ),
            _ItemCategoria(
              nome: 'Backup e restauração',
              selected: atual == '/backup',
              altura: 40,
              comBolinha: false,
              onTap: () => _navegar(context, '/backup'),
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Divider(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          _ItemCategoria(
            nome: 'Sair',
            selected: false,
            altura: 40,
            comBolinha: false,
            onTap: () {
              Scaffold.of(context).closeDrawer();
              ref.read(sessionProvider.notifier).sair();
            },
          ),
        ],
      ),
    );
  }
}

Widget drawerMenuButton(BuildContext context) => Builder(
  builder: (scaffoldContext) => IconButton(
    tooltip: 'Abrir menu',
    icon: const Icon(Icons.menu),
    onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
  ),
);

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
    final alturaMinima = MediaQuery.textScalerOf(context).scale(15) + 12;
    return Container(
      constraints: BoxConstraints(
        minHeight: alturaMinima > 46 ? alturaMinima : 46,
      ),
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
    final alturaEscalada = MediaQuery.textScalerOf(context).scale(14) + 12;
    return Container(
      constraints: BoxConstraints(
        minHeight: alturaEscalada > altura ? alturaEscalada : altura,
      ),
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
                    color: CategoriaCores.de(
                      nome,
                      Theme.of(context).brightness,
                    ),
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
