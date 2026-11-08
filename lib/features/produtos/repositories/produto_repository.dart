import 'package:sqflite/sqflite.dart';

import 'package:projeto_2/core/database/app_database.dart';
import 'package:projeto_2/core/database/contexto_trabalho_repository.dart';
import 'package:projeto_2/core/utils/app_exception.dart';
import 'package:projeto_2/core/utils/texto_utils.dart';
import 'package:projeto_2/features/produtos/models/produto.dart';

class ProdutoRepository {
  ProdutoRepository(this._appDb);

  final AppDatabase _appDb;

  static const String _select = '''
    SELECT p.id, p.nome, p.categoria_id, c.nome AS categoria_nome,
           p.unidade_id, u.sigla AS unidade_sigla,
           u.fracionavel AS unidade_fracionavel,
           p.saldo, p.ativo
    FROM produtos p
    JOIN categorias c
      ON c.id = p.categoria_id AND c.contexto_id = p.contexto_id
    JOIN unidades u
      ON u.id = p.unidade_id AND u.contexto_id = p.contexto_id
  ''';

  Future<List<Produto>> listar({
    String busca = '',
    int? categoriaId,
    bool incluirInativos = false,
  }) async {
    final db = await _appDb.database;
    final contextoId = await ContextoTrabalhoRepository.exigirIdAtivo(db);
    final filtros = <String>[
      'p.contexto_id = ?',
      'c.contexto_id = ?',
      'u.contexto_id = ?',
    ];
    final args = <Object?>[contextoId, contextoId, contextoId];
    if (!incluirInativos) filtros.add('p.ativo = 1');
    if (categoriaId != null) {
      filtros.add('p.categoria_id = ?');
      args.add(categoriaId);
    }
    final condicao = filtros.join(' AND ');
    final clausula = condicao.isEmpty ? '' : 'WHERE $condicao';
    final rows = await db.rawQuery(
      '$_select $clausula ORDER BY p.nome COLLATE NOCASE',
      args,
    );

    var lista = rows.map(Produto.fromMap).toList();
    final termo = TextoUtils.normalizar(busca);
    if (termo.isNotEmpty) {
      lista = lista
          .where((p) => TextoUtils.normalizar(p.nome).contains(termo))
          .toList();
    }
    return lista;
  }

  Future<Produto?> buscarPorId(int id) async {
    final db = await _appDb.database;
    final contextoId = await ContextoTrabalhoRepository.exigirIdAtivo(db);
    final rows = await db.rawQuery(
      '$_select WHERE p.id = ? AND p.contexto_id = ?',
      [id, contextoId],
    );
    return rows.isEmpty ? null : Produto.fromMap(rows.first);
  }

  Future<bool> temMovimentacoes(int produtoId) async {
    final db = await _appDb.database;
    final contextoId = await ContextoTrabalhoRepository.exigirIdAtivo(db);
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM movimentacoes '
      'WHERE produto_id = ? AND contexto_id = ?',
      [produtoId, contextoId],
    );
    return (Sqflite.firstIntValue(r) ?? 0) > 0;
  }

  Future<void> excluir(int produtoId) async {
    final db = await _appDb.database;
    final contextoId = await ContextoTrabalhoRepository.exigirIdAtivo(db);
    final produto = await db.query(
      'produtos',
      columns: ['saldo'],
      where: 'id = ? AND contexto_id = ?',
      whereArgs: [produtoId, contextoId],
      limit: 1,
    );
    if (produto.isEmpty) {
      throw const AppException('Produto não encontrado.');
    }
    final movimentacoes = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM movimentacoes '
      'WHERE produto_id = ? AND contexto_id = ?',
      [produtoId, contextoId],
    );
    final itensInventario = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM itens_inventario '
      'WHERE produto_id = ? AND contexto_id = ?',
      [produtoId, contextoId],
    );
    if ((Sqflite.firstIntValue(movimentacoes) ?? 0) > 0 ||
        (Sqflite.firstIntValue(itensInventario) ?? 0) > 0) {
      throw const AppException(
        'Não é possível excluir o produto: existem movimentações ou inventários vinculados.',
      );
    }
    if ((produto.first['saldo'] as int) != 0) {
      throw const AppException(
        'Não é possível excluir o produto enquanto houver saldo em estoque.',
      );
    }
    await db.delete(
      'produtos',
      where: 'id = ? AND contexto_id = ?',
      whereArgs: [produtoId, contextoId],
    );
  }

  /// O produto nasce com saldo 0. O estoque inicial entra como "entrada".
  Future<int> criar({
    required String nome,
    required int categoriaId,
    required int unidadeId,
    required int usuarioId,
  }) async {
    final db = await _appDb.database;
    final contextoId = await ContextoTrabalhoRepository.exigirIdAtivo(db);
    final nomeLimpo = nome.trim();
    if (nomeLimpo.isEmpty) {
      throw const AppException('Informe o nome do produto.');
    }
    await _validarNomeUnico(db, nomeLimpo, contextoId: contextoId);

    return db.insert('produtos', {
      'nome': nomeLimpo,
      'categoria_id': categoriaId,
      'unidade_id': unidadeId,
      'saldo': 0,
      'ativo': 1,
      'criado_em': DateTime.now().toIso8601String(),
      'criado_por': usuarioId,
      'contexto_id': contextoId,
    });
  }

  Future<void> atualizar({
    required int id,
    required String nome,
    required int categoriaId,
    required int unidadeId,
  }) async {
    final db = await _appDb.database;
    final contextoId = await ContextoTrabalhoRepository.exigirIdAtivo(db);
    final nomeLimpo = nome.trim();
    if (nomeLimpo.isEmpty) {
      throw const AppException('Informe o nome do produto.');
    }
    await _validarNomeUnico(
      db,
      nomeLimpo,
      contextoId: contextoId,
      ignorarId: id,
    );

    final atual = await db.query(
      'produtos',
      columns: ['unidade_id'],
      where: 'id = ? AND contexto_id = ?',
      whereArgs: [id, contextoId],
      limit: 1,
    );
    if (atual.isEmpty) {
      throw const AppException('Produto não encontrado.');
    }
    if (atual.first['unidade_id'] != unidadeId && await temMovimentacoes(id)) {
      throw const AppException(
        'A unidade não pode ser alterada: o produto já tem movimentações.',
      );
    }

    await db.update(
      'produtos',
      {'nome': nomeLimpo, 'categoria_id': categoriaId, 'unidade_id': unidadeId},
      where: 'id = ? AND contexto_id = ?',
      whereArgs: [id, contextoId],
    );
  }

  Future<void> definirAtivo(int id, bool ativo) async {
    final db = await _appDb.database;
    final contextoId = await ContextoTrabalhoRepository.exigirIdAtivo(db);
    if (!ativo) {
      final r = await db.query(
        'produtos',
        columns: ['saldo'],
        where: 'id = ? AND contexto_id = ?',
        whereArgs: [id, contextoId],
        limit: 1,
      );
      if (r.isNotEmpty && (r.first['saldo'] as int) != 0) {
        throw const AppException(
          'Zere o saldo do produto (saída ou ajuste) antes de inativá-lo.',
        );
      }
    }
    await db.update(
      'produtos',
      {'ativo': ativo ? 1 : 0},
      where: 'id = ? AND contexto_id = ?',
      whereArgs: [id, contextoId],
    );
  }

  Future<void> _validarNomeUnico(
    DatabaseExecutor db,
    String nome, {
    required String contextoId,
    int? ignorarId,
  }) async {
    final rows = await db.query(
      'produtos',
      columns: ['id', 'nome'],
      where: 'contexto_id = ?',
      whereArgs: [contextoId],
    );
    final alvo = TextoUtils.normalizar(nome);
    for (final r in rows) {
      if (r['id'] == ignorarId) continue;
      if (TextoUtils.normalizar(r['nome'] as String) == alvo) {
        throw const AppException('Já existe um produto com este nome.');
      }
    }
  }
}
