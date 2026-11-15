import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:projeto_2/core/database/app_database.dart';
import 'package:projeto_2/features/produtos/models/unidade.dart';
import 'package:projeto_2/features/produtos/providers/produto_providers.dart';
import 'package:projeto_2/features/produtos/repositories/unidade_repository.dart';
import 'package:projeto_2/features/produtos/screens/unidades_screen.dart';

void main() {
  testWidgets('cadastro fecha o diálogo sem descarte de controller pendente', (
    tester,
  ) async {
    final repository = _UnidadeRepositoryTeste();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          unidadeRepositoryProvider.overrideWithValue(repository),
          unidadesTodasProvider.overrideWith((ref) async => const []),
          unidadesAtivasProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: UnidadesScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'cx2');
    await tester.enterText(find.byType(TextField).at(1), 'Caixa especial');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(repository.siglaCriada, 'cx2');
    expect(repository.nomeCriado, 'Caixa especial');
    expect(tester.takeException(), isNull);
  });
}

class _UnidadeRepositoryTeste extends UnidadeRepository {
  _UnidadeRepositoryTeste() : super(AppDatabase.instance);

  String? siglaCriada;
  String? nomeCriado;

  @override
  Future<List<Unidade>> listar({bool incluirInativas = false}) async => [];

  @override
  Future<void> criar({
    required String sigla,
    required String nome,
    required bool fracionavel,
  }) async {
    siglaCriada = sigla;
    nomeCriado = nome;
  }
}
