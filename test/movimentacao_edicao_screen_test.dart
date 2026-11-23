import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_2/features/auth/models/usuario.dart';
import 'package:projeto_2/features/auth/providers/auth_providers.dart';
import 'package:projeto_2/features/historico/providers/historico_providers.dart';
import 'package:projeto_2/features/historico/repositories/historico_repository.dart';
import 'package:projeto_2/features/historico/screens/historico_screen.dart';
import 'package:projeto_2/features/movimentacoes/models/movimentacao.dart';
import 'package:projeto_2/features/movimentacoes/providers/movimentacao_providers.dart';
import 'package:projeto_2/features/movimentacoes/repositories/movimentacao_repository.dart';
import 'package:projeto_2/features/movimentacoes/screens/movimentacao_form_screen.dart';
import 'package:projeto_2/features/produtos/models/produto.dart';
import 'package:projeto_2/features/produtos/providers/produto_providers.dart';

const _produto = Produto(
  id: 1,
  nome: 'Arroz teste',
  categoriaId: 1,
  categoriaNome: 'Teste',
  unidadeId: 1,
  unidadeSigla: 'un',
  unidadeFracionavel: false,
  saldo: 7000,
  ativo: true,
);

Movimentacao _mov(int id, TipoMovimentacao tipo) => Movimentacao(
  id: id,
  produtoId: 1,
  tipo: tipo,
  finalidade: null,
  delta: tipo == TipoMovimentacao.entrada ? 10000 : -3000,
  saldoApos: 7000,
  dataHora: DateTime(2026, 11, 22),
  usuarioId: 2,
  usuarioNome: 'Operador',
  observacao: null,
);

class _Sessao extends SessionController {
  @override
  Future<Usuario?> build() async => const Usuario(
    id: 1,
    nome: 'Admin',
    login: 'teste',
    perfil: 'admin',
    ativo: true,
  );
}

class _Repositorio extends MovimentacaoRepository {
  _Repositorio()
    : super(() async => throw StateError('Banco fora deste teste'));
  ({int id, int usuarioId, int anterior, int nova})? correcao;
  @override
  Future<int> quantidadeEfetiva(int id) async => 10000;
  @override
  Future<void> retificar({
    required int id,
    required int usuarioId,
    required int anterior,
    required int nova,
  }) async {
    correcao = (id: id, usuarioId: usuarioId, anterior: anterior, nova: nova);
  }
}

void main() {
  testWidgets(
    'últimas movimentações oferecem toque longo e menu somente para registros elegíveis',
    (tester) async {
      final repo = _Repositorio();
      final linhas = [
        _mov(1, TipoMovimentacao.entrada),
        _mov(2, TipoMovimentacao.saida),
        _mov(3, TipoMovimentacao.perda),
        _mov(4, TipoMovimentacao.ajuste),
        _mov(5, TipoMovimentacao.entrada),
      ];
      await tester.binding.setSurfaceSize(const Size(800, 1500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(_Sessao.new),
            produtoPorIdProvider.overrideWith((ref, id) async => _produto),
            ultimasMovimentacoesProvider.overrideWith(
              (ref, id) async => linhas,
            ),
            retificaveisDoProdutoProvider.overrideWith(
              (ref, filtro) async => {1, 2},
            ),
            movimentacaoRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(home: MovimentacaoFormScreen(produtoId: 1)),
        ),
      );
      await tester.pumpAndSettle();
      Finder linha(int id) => find.byKey(ValueKey('movimentacao-$id'));
      Finder menu(int id) => find.descendant(
        of: linha(id),
        matching: find.byTooltip('Opções da movimentação'),
      );
      for (final id in [3, 4, 5]) {
        await tester.ensureVisible(linha(id));
        expect(menu(id), findsNothing);
        await tester.longPress(linha(id));
        await tester.pumpAndSettle();
        expect(find.text('Editar movimentação'), findsNothing);
      }
      await tester.ensureVisible(linha(2));
      await tester.tap(menu(2));
      await tester.pumpAndSettle();
      expect(find.text('Editar movimentação'), findsOneWidget);
      Navigator.of(tester.element(find.text('Editar movimentação'))).pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(linha(1));
      await tester.longPress(linha(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar movimentação'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextFormField),
        ),
        '12',
      );
      await tester.pump();
      await tester.tap(find.text('Revisar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('10 → 12'), findsOneWidget);
      expect(repo.correcao, isNull);
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(repo.correcao, (
        id: 1,
        usuarioId: 1,
        anterior: 10000,
        nova: 12000,
      ));
    },
  );

  testWidgets(
    'histórico exibe o lançamento sem ações de edição, inclusive para administrador',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(_Sessao.new),
            historicoProvider.overrideWith(
              (ref) async => HistoricoPagina([
                HistoricoItem(
                  movimentacao: _mov(1, TipoMovimentacao.entrada),
                  produtoNome: 'Arroz teste',
                  unidadeSigla: 'un',
                  fracionavel: false,
                ),
              ], false),
            ),
          ],
          child: const MaterialApp(home: HistoricoScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Opções da movimentação'), findsNothing);
      await tester.longPress(find.text('Arroz teste'));
      await tester.pumpAndSettle();
      expect(find.text('Editar movimentação'), findsNothing);
      expect(find.text('Saldo após: 7 un'), findsOneWidget);
    },
  );
}
