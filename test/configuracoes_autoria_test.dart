import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_2/features/configuracoes/providers/tema_provider.dart';
import 'package:projeto_2/features/configuracoes/screens/configuracoes_screen.dart';

class _TemaTeste extends TemaController {
  @override
  Future<ThemeMode> build() async => ThemeMode.system;
}

void main() {
  const canal = MethodChannel('estoque_uan/app_info');

  Future<void> abrirConfiguracoes(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [temaProvider.overrideWith(_TemaTeste.new)],
        child: const MaterialApp(home: ConfiguracoesScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Sobre o aplicativo'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('exibe os créditos e a versão informada pelo Android', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(canal, (call) async {
      expect(call.method, 'versionName');
      return '7.8.9';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(canal, null));

    await abrirConfiguracoes(tester);
    expect(find.text('Sobre o aplicativo'), findsOneWidget);
    expect(find.text('Estoque UAN'), findsOneWidget);
    expect(find.text('Versão 7.8.9'), findsOneWidget);
    expect(find.text('Desenvolvido por'), findsOneWidget);
    expect(find.text('Neis Bila de Alencar'), findsOneWidget);
    expect(find.text('Direitos autorais'), findsOneWidget);
    expect(
      find.text('© 2026 Neis Bila de Alencar. Todos os direitos reservados.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'os créditos continuam visíveis quando a versão está indisponível',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(canal, (call) async {
        throw MissingPluginException('Canal indisponível');
      });
      addTearDown(() => messenger.setMockMethodCallHandler(canal, null));

      await abrirConfiguracoes(tester);
      expect(find.text('Versão indisponível'), findsOneWidget);
      expect(find.text('Neis Bila de Alencar'), findsOneWidget);
    },
  );
}
