import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:projeto_2/features/auth/models/usuario.dart';
import 'package:projeto_2/features/auth/providers/auth_providers.dart';
import 'package:projeto_2/features/perfil/screens/perfil_screen.dart';
import 'package:projeto_2/features/perfil/providers/tamanho_texto_provider.dart';
import 'package:projeto_2/features/perfil/widgets/tamanho_texto_app.dart';
import 'package:projeto_2/features/produtos/providers/produto_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'tamanho padrão, opções e preferência persistida após novo container',
    () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(await container.read(tamanhoTextoProvider.future), 1.0);
      for (final fator in [0.8, 0.95, 1.15, 1.4, 1.6]) {
        await container.read(tamanhoTextoProvider.notifier).definir(fator);
        expect(await container.read(tamanhoTextoProvider.future), fator);
      }

      final reiniciado = ProviderContainer();
      addTearDown(reiniciado.dispose);
      expect(
        await reiniciado.read(tamanhoTextoProvider.future),
        1.6,
      );
      final preferencias = await SharedPreferences.getInstance();
      expect(
        preferencias.getDouble('tamanho_texto_aplicativo'),
        1.6,
      );
    },
  );

  test('migra preferência antiga de rótulo para fator contínuo', () async {
    SharedPreferences.setMockInitialValues({
      'tamanho_texto_aplicativo': 'extra_grande',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(tamanhoTextoProvider.future), 1.5);
    await container.read(tamanhoTextoProvider.notifier).definir(1.35);
    final preferencias = await SharedPreferences.getInstance();
    expect(preferencias.getDouble('tamanho_texto_aplicativo'), 1.35);
  });

  testWidgets('escalonamento é aplicado à árvore global e atualiza na hora', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    TextScaler? escalaRecebida;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: TamanhoTextoApp(
            child: Builder(
              builder: (context) {
                escalaRecebida = MediaQuery.textScalerOf(context);
                return const Scaffold(
                  body: Column(
                    children: [
                      Text('Texto global'),
                      ListTile(title: Text('Menu')),
                      FilledButton(onPressed: null, child: Text('Ação')),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await container.read(tamanhoTextoProvider.future);
    await tester.pumpAndSettle();
    expect(escalaRecebida!.scale(14), 14);
    expect(find.text('Texto global'), findsOneWidget);

    await container
        .read(tamanhoTextoProvider.notifier)
        .definir(1.5);
    await tester.pumpAndSettle();
    expect(escalaRecebida!.scale(14), 21);
    expect(find.text('Menu'), findsOneWidget);
    expect(find.text('Ação'), findsOneWidget);
  });

  testWidgets(
    'Perfil permite ajustar o slider sem overflow e salva a preferência',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        initialLocation: '/perfil',
        routes: [
          GoRoute(path: '/perfil', builder: (_, _) => const PerfilScreen()),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(_SessaoTeste.new),
            categoriasAtivasProvider.overrideWith((ref) async => []),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (_, child) =>
                TamanhoTextoApp(child: child ?? const SizedBox.shrink()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Acessibilidade'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('Tamanho do texto em todo o aplicativo: 100%'), findsOneWidget);
      await tester.ensureVisible(find.byType(Slider));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Slider), const Offset(100, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final preferencias = await SharedPreferences.getInstance();
      expect(preferencias.getDouble('tamanho_texto_aplicativo'), greaterThan(1));
    },
  );
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
