import 'package:android_file_picker/android_file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_2/features/relatorios/providers/relatorio_providers.dart';
import 'package:projeto_2/features/relatorios/screens/menu_pdf.dart';
import 'package:projeto_2/features/relatorios/screens/relatorios_screen.dart';

void main() {
  testWidgets('navega entre relatórios e seleciona dia e intervalo', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          estoqueRelatorioProvider.overrideWith((ref) async => []),
          movimentacoesRelatorioProvider.overrideWith(
            (ref, periodo) async => [],
          ),
        ],
        child: const MaterialApp(home: RelatoriosScreen()),
      ),
    );
    await tester.tap(find.text('Posição atual do estoque'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum produto cadastrado.'), findsOneWidget);
    expect(find.text('Um dia'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Movimentações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Um dia'));
    await tester.pumpAndSettle();
    expect(find.text('Dia das movimentações'), findsOneWidget);
    await tester.tap(find.text('Intervalo'));
    await tester.pumpAndSettle();
    expect(find.text('Intervalo das movimentações'), findsOneWidget);
  });
  testWidgets('salvar envia bytes e MIME do PDF ao seletor Android', (
    tester,
  ) async {
    FilePickerAndroid.registerWith();
    MethodCall? chamada;
    const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      chamada = call;
      return 'content://teste/document/estoque.pdf';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final bytes = Uint8List.fromList([37, 80, 68, 70]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MenuPdf(gerar: () async => (nome: 'estoque.pdf', bytes: bytes)),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Opções de PDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar PDF no dispositivo'));
    await tester.pumpAndSettle();
    expect(chamada?.method, 'save');
    expect(chamada?.arguments['bytes'], bytes);
    expect(chamada?.arguments['fileType'], 'application/pdf');
    expect(find.text('PDF salvo.'), findsOneWidget);
  });
}
