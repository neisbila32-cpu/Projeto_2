import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:projeto_2/features/auth/models/usuario.dart';
import 'package:projeto_2/features/auth/providers/auth_providers.dart';
import 'package:projeto_2/features/home/widgets/app_drawer.dart';
import 'package:projeto_2/features/produtos/providers/produto_providers.dart';

void main() {
  late GoRouter router;

  setUp(() {
    router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const _TelaPrincipal(titulo: 'Produtos'),
        ),
        GoRoute(
          path: '/painel',
          builder: (context, state) => const _TelaPrincipal(titulo: 'Painel'),
        ),
        GoRoute(
          path: '/relatorios',
          builder: (context, state) =>
              const _TelaPrincipal(titulo: 'Relatórios'),
        ),
        GoRoute(
          path: '/detalhe',
          builder: (context, state) => Scaffold(
            appBar: AppBar(title: const Text('Detalhe')),
            body: const Text('Tela secundária'),
          ),
        ),
      ],
    );
  });

  tearDown(() => router.dispose());

  testWidgets('Drawer troca telas principais e voltar retorna à raiz', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(_SessaoTeste.new),
          categoriasAtivasProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Abrir menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Painel'));
    await tester.pumpAndSettle();
    expect(find.text('Painel'), findsOneWidget);

    await tester.tap(find.byTooltip('Abrir menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Relatórios'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Abrir menu'), findsOneWidget);

    await tester.tap(find.text('Abrir detalhe'));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Relatórios'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Produtos'), findsOneWidget);
  });
}

class _SessaoTeste extends SessionController {
  @override
  Future<Usuario?> build() async => const Usuario(
    id: 1,
    nome: 'Teste',
    login: 'teste',
    perfil: 'admin',
    ativo: true,
  );
}

class _TelaPrincipal extends StatelessWidget {
  const _TelaPrincipal({required this.titulo});

  final String titulo;

  @override
  Widget build(BuildContext context) => Scaffold(
    drawer: const AppDrawer(),
    appBar: AppBar(
      automaticallyImplyLeading: false,
      leading: drawerMenuButton(context),
      title: Text(titulo),
    ),
    body: Center(
      child: ElevatedButton(
        onPressed: () => context.push('/detalhe'),
        child: const Text('Abrir detalhe'),
      ),
    ),
  );
}
