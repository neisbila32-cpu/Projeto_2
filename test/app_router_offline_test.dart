import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:projeto_2/core/routes/app_router.dart';
import 'package:projeto_2/features/auth/models/usuario.dart';
import 'package:projeto_2/features/auth/providers/auth_providers.dart';

void main() {
  testWidgets('login e recuperação locais continuam disponíveis offline', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(_SessaoLocalAusente.new),
        existeUsuarioProvider.overrideWith((ref) async => true),
      ],
    );
    addTearDown(container.dispose);

    final router = container.read(routerProvider);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Esqueci minha senha'), findsOneWidget);
    expect(find.text('Áreas compartilhadas'), findsNothing);

    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pumpAndSettle();

    expect(find.text('Recuperar senha'), findsOneWidget);
    expect(find.text('Login do administrador'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _SessaoLocalAusente extends SessionController {
  @override
  Future<Usuario?> build() async => null;
}
