import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:projeto_2/features/historico/providers/historico_providers.dart';
import 'package:projeto_2/features/historico/repositories/historico_repository.dart';
import 'package:projeto_2/features/historico/screens/historico_screen.dart';

void main() {
  testWidgets('histórico oferece 30 dias sem a opção redundante do mês', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historicoProvider.overrideWith(
            (ref) async => const HistoricoPagina([], false),
          ),
        ],
        child: const MaterialApp(home: HistoricoScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('30 dias'), findsOneWidget);
    expect(find.text('Este mês'), findsNothing);
  });
}
