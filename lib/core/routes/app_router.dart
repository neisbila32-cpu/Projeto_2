import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:projeto_2/features/auth/providers/auth_providers.dart';
import 'package:projeto_2/features/auth/screens/cadastro_screen.dart';
import 'package:projeto_2/features/auth/screens/login_screen.dart';
import 'package:projeto_2/features/auth/screens/recuperar_senha_screen.dart';
import 'package:projeto_2/features/home/screens/home_screen.dart';
import 'package:projeto_2/features/movimentacoes/screens/movimentacao_form_screen.dart';
import 'package:projeto_2/features/produtos/screens/categorias_screen.dart';
import 'package:projeto_2/features/produtos/screens/produto_form_screen.dart';
import 'package:projeto_2/features/produtos/screens/unidades_screen.dart';
import 'package:projeto_2/core/routes/foco_observer.dart';

const Set<String> _rotasPublicas = {'/login', '/cadastro', '/recuperar-senha'};

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (previous, next) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    observers: [FocoObserver()],
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final local = state.matchedLocation;

      if (session.isLoading) return local == '/splash' ? null : '/splash';
      final logado = session.value != null;
      if (!logado) return _rotasPublicas.contains(local) ? null : '/login';
      if (_rotasPublicas.contains(local) || local == '/splash') return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const _SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/cadastro',
        builder: (context, state) => const CadastroScreen(),
      ),
      GoRoute(
        path: '/recuperar-senha',
        builder: (context, state) => const RecuperarSenhaScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/produtos/novo',
        builder: (context, state) => const ProdutoFormScreen(),
      ),
      GoRoute(
        path: '/produtos/:id/editar',
        builder: (context, state) => ProdutoFormScreen(
          produtoId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/categorias',
        builder: (context, state) => const CategoriasScreen(),
      ),
      GoRoute(
        path: '/unidades',
        builder: (context, state) => const UnidadesScreen(),
      ),
      GoRoute(
        path: '/produtos/:id/movimentar',
        builder: (context, state) => MovimentacaoFormScreen(
          produtoId: int.parse(state.pathParameters['id']!),
        ),
      ),
    ],
  );
});

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
