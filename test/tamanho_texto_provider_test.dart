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

      expect(
        await container.read(tamanhoTextoProvider.future),
        TamanhoTexto.padrao,
      );
      for (final tamanho in TamanhoTexto.values) {
        await container.read(tamanhoTextoProvider.notifier).definir(tamanho);
        expect(await container.read(tamanhoTextoProvider.future), tamanho);
      }

      final reiniciado = ProviderContainer();
      addTearDown(reiniciado.dispose);
      expect(
        await reiniciado.read(tamanhoTextoProvider.future),
        TamanhoTexto.extraGrande,
      );
      final preferencias = await SharedPreferences.getInstance();
      expect(
        preferencias.getString('tamanho_texto_aplicativo'),
        'extra_grande',
      );
    },
  );

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
        .definir(TamanhoTexto.extraGrande);
    await tester.pumpAndSettle();
    expect(escalaRecebida!.scale(14), 21);
    expect(find.text('Menu'), findsOneWidget);
    expect(find.text('Ação'), findsOneWidget);
  });

  testWidgets(
    'Perfil permite escolher tamanhos sem overflow em tela estreita',
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
      for (final tamanho in TamanhoTexto.values) {
        expect(find.text(tamanho.rotulo), findsOneWidget);
      }
      await tester.ensureVisible(find.text('Extra grande'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Extra grande'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
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
