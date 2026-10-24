import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meu_app_android/main.dart';

void main() {
  testWidgets('App abre e mostra tela de login', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    expect(
      find.text('Tela de login (em construcao)'),
      findsOneWidget,
    );
  });
}
