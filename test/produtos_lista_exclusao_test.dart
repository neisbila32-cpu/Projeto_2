import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:projeto_2/features/produtos/models/produto.dart';
import 'package:projeto_2/features/produtos/providers/produto_providers.dart';
import 'package:projeto_2/features/produtos/widgets/produtos_lista_view.dart';

void main() {
  const produto = Produto(
    id: 1,
    nome: 'Arroz integral',
    categoriaId: 1,
    categoriaNome: 'Mercearia',
    unidadeId: 1,
    unidadeSigla: 'kg',
    unidadeFracionavel: true,
    saldo: 5000,
    ativo: true,
  );

  testWidgets('lista de produtos mostra lixeira e pede confirmação', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          produtosProvider.overrideWith((ref) async => [produto]),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ProdutosListaView(mostrarCategorias: false)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final lixeira = find.byTooltip('Excluir produto');
    expect(lixeira, findsOneWidget);
    await tester.tap(lixeira);
    await tester.pumpAndSettle();
    expect(find.text('Excluir produto'), findsOneWidget);
    expect(
      find.text('Deseja excluir o produto "Arroz integral"?'),
      findsOneWidget,
    );
  });

  testWidgets('seletor de produto não apresenta ação de exclusão', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          produtosProvider.overrideWith((ref) async => [produto]),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ProdutosListaView(mostrarCategorias: false, aoTocar: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Excluir produto'), findsNothing);
  });
}
