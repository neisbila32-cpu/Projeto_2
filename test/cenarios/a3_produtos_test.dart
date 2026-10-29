import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:projeto_2/core/database/app_database.dart';
import 'package:projeto_2/core/utils/app_exception.dart';
import 'package:projeto_2/features/movimentacoes/models/movimentacao.dart';
import 'package:projeto_2/features/movimentacoes/repositories/movimentacao_repository.dart';
import 'package:projeto_2/features/produtos/repositories/produto_repository.dart';
import 'apoio/banco_teste.dart';

void main() {
  group('A3 Produtos', () {
    late ProdutoRepository prodRepo;
    late MovimentacaoRepository movRepo;
    late Database db;
    late int categoriaId;
    late int unidadeId;
    late int usuarioId;

    setUpAll(() async {
      await abrirBancoEmMemoria();
      db = await AppDatabase.instance.database;
      prodRepo = ProdutoRepository(AppDatabase.instance);
      movRepo = MovimentacaoRepository(() async => db);
    });

    setUp(() async {
      await limparDados(db);
      // usuário para created_por (usa o id real retornado pelo insert, pois
      // o autoincrement não é resetado pelo limparDados entre testes)
      usuarioId = await db.insert('usuarios', {
        'nome': 'Admin',
        'login': 'admin',
        'senha_hash': 'hash',
        'senha_salt': 'salt',
        'perfil': 'admin',
        'ativo': 1,
        'criado_em': DateTime.now().toIso8601String(),
      });
      // categoria e unidade para os produtos
      final cat = await db.query('categorias', limit: 1);
      categoriaId = cat.first['id'] as int;
      final uni = await db.query('unidades', limit: 1);
      unidadeId = uni.first['id'] as int;
    });

    Future<void> deveLancarAppException(Future<void> Function() acao) async {
      try {
        await acao();
        fail('Deveria lançar AppException');
      } on AppException {
        // esperado
      }
    }

    test('produto nasce com saldo 0 e ativo', () async {
      final id = await prodRepo.criar(
        nome: 'Arroz tipo 1',
        categoriaId: categoriaId,
        unidadeId: unidadeId,
        usuarioId: usuarioId,
      );
      final p = await prodRepo.buscarPorId(id);
      expect(p, isNotNull);
      expect(p!.saldo, 0);
      expect(p.ativo, isTrue);
    });

    test('nome duplicado é recusado (arroz branco x Arroz Branco x variações com acento)', () async {
      await prodRepo.criar(
        nome: 'arroz branco',
        categoriaId: categoriaId,
        unidadeId: unidadeId,
        usuarioId: usuarioId,
      );
      // mesmo nome com maiúscula
      await deveLancarAppException(
        () => prodRepo.criar(
          nome: 'Arroz Branco',
          categoriaId: categoriaId,
          unidadeId: unidadeId,
          usuarioId: usuarioId,
        ),
      );
      // variação com acento (â -> a)
      await deveLancarAppException(
        () => prodRepo.criar(
          nome: 'arroz brânco',
          categoriaId: categoriaId,
          unidadeId: unidadeId,
          usuarioId: usuarioId,
        ),
      );
    });

    test('só inativa com saldo zero; reativa', () async {
      final id = await prodRepo.criar(
        nome: 'Feijão',
        categoriaId: categoriaId,
        unidadeId: unidadeId,
        usuarioId: usuarioId,
      );
      // com saldo 0 pode inativar
      await prodRepo.definirAtivo(id, false);
      final p = await prodRepo.buscarPorId(id);
      expect(p!.ativo, isFalse);

      // reativa
      await prodRepo.definirAtivo(id, true);
      final p2 = await prodRepo.buscarPorId(id);
      expect(p2!.ativo, isTrue);
    });

    test('busca ignora maiúsculas e acentos (feijao acha Feijão)', () async {
      await prodRepo.criar(
        nome: 'Feijão',
        categoriaId: categoriaId,
        unidadeId: unidadeId,
        usuarioId: usuarioId,
      );
      final encontrados = await prodRepo.listar(busca: 'feijao');
      expect(encontrados.any((p) => p.nome == 'Feijão'), isTrue);
    });

    test('filtro por categoria', () async {
      await prodRepo.criar(
        nome: 'Produto Cat A',
        categoriaId: categoriaId,
        unidadeId: unidadeId,
        usuarioId: usuarioId,
      );
      // cria uma segunda categoria
      await db.insert('categorias', {'nome': 'Categoria Z'});
      final catZ = await db.query('categorias', where: 'nome = ?', whereArgs: ['Categoria Z']);
      await prodRepo.criar(
        nome: 'Produto Cat Z',
        categoriaId: catZ.first['id'] as int,
        unidadeId: unidadeId,
        usuarioId: usuarioId,
      );
      final apenasCatA = await prodRepo.listar(categoriaId: categoriaId);
      expect(apenasCatA.every((p) => p.categoriaId == categoriaId), isTrue);
    });

    test('unidade fica travada depois da primeira movimentação', () async {
      final id = await prodRepo.criar(
        nome: 'Produto travável',
        categoriaId: categoriaId,
        unidadeId: unidadeId,
        usuarioId: usuarioId,
      );
      await movRepo.registrar(
        produtoId: id,
        tipo: TipoMovimentacao.entrada,
        valor: 1000,
        usuarioId: usuarioId,
      );

      // tentar mudar a unidade deve falhar
      final outraUnidade = await db.query(
        'unidades', where: 'id != ?', whereArgs: [unidadeId], limit: 1,
      );
      if (outraUnidade.isNotEmpty) {
        await deveLancarAppException(
          () => prodRepo.atualizar(
            id: id,
            nome: 'Produto travável',
            categoriaId: categoriaId,
            unidadeId: outraUnidade.first['id'] as int,
          ),
        );
      }
    });
  });
}
