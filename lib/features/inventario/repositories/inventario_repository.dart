import 'package:sqflite/sqflite.dart';
import 'package:projeto_2/core/database/contexto_trabalho_repository.dart';
import 'package:projeto_2/core/utils/app_exception.dart';
import 'package:projeto_2/features/inventario/models/inventario.dart';
import 'package:projeto_2/features/inventario/models/inventario_regras.dart';

class ResultadoFinalizacao {
  final int ajustados;
  final int semDivergencia;
  const ResultadoFinalizacao(this.ajustados, this.semDivergencia);
}

class InventarioRepository {
  InventarioRepository(this._obterBanco);

  final Future<Database> Function() _obterBanco;

  static const String _selectInventario =
      'SELECT i.*, u.nome AS usuario_nome, '
      '(SELECT COUNT(*) FROM itens_inventario x WHERE x.inventario_id = i.id AND x.contexto_id = i.contexto_id) AS total_itens, '
      '(SELECT COUNT(*) FROM itens_inventario x WHERE x.inventario_id = i.id AND x.contexto_id = i.contexto_id AND x.divergencia <> 0) AS total_divergentes '
      'FROM inventarios i JOIN usuarios u ON u.id = i.usuario_id AND u.contexto_id = i.contexto_id';

  Future<Inventario?> emAndamento() async {
    final db = await _obterBanco();
    final contextoId = await ContextoTrabalhoRepository.exigirIdAtivo(db);
    final l = await db.rawQuery(
      "$_selectInventario WHERE i.contexto_id = ? AND i.status = 'em_andamento' ORDER BY i.id DESC LIMIT 1",
      [contextoId],
    );
    return l.isEmpty ? null : Inventario.fromMap(l.first);
  }

  Future<Inventario?> porId(int id) async {
    final db = await _obterBanco();
    final contextoId = await ContextoTrabalhoRepository.exigirIdAtivo(db);
    final l = await db.rawQuery(
      '$_selectInventario WHERE i.id = ? AND i.contexto_id = ?',
      [id, contextoId],
    );
    return l.isEmpty ? null : Inventario.fromMap(l.first);
  }

  Future<List<Inventario>> listar({int limite = 50}) async {
    final db = await _obterBanco();
    final contextoId = await ContextoTrabalhoRepository.exigirIdAtivo(db);
    final l = await db.rawQuery(
      '$_selectInventario WHERE i.contexto_id = ? ORDER BY i.id DESC LIMIT ?',
      [contextoId, limite],
    );
    return l.map(Inventario.fromMap).toList();
  }

  Future<List<ItemInventario>> itens(int inventarioId) async {
    final db = await _obterBanco();
    final contextoId = await ContextoTrabalhoRepository.exigirIdAtivo(db);
    final l = await db.rawQuery(
      'SELECT i.*, p.nome AS produto_nome, un.sigla AS unidade_sigla, '
      'un.fracionavel AS fracionavel '
      'FROM itens_inventario i '
      'JOIN produtos p ON p.id = i.produto_id '
      'JOIN unidades un ON un.id = p.unidade_id AND un.contexto_id = p.contexto_id '
      'WHERE i.inventario_id = ? AND i.contexto_id = ? '
      'AND p.contexto_id = i.contexto_id ORDER BY p.nome COLLATE NOCASE',
      [inventarioId, contextoId],
    );
    return l.map(ItemInventario.fromMap).toList();
  }

  Future<List<AuditoriaItemInventario>> auditoria(int inventarioId) async {
    final db = await _obterBanco();
    final contextoId = await ContextoTrabalhoRepository.exigirIdAtivo(db);
    final linhas = await db.rawQuery(
      'SELECT i.id AS item_id, i.inventario_id AS inventario_id, '
      'i.produto_id AS produto_id, p.nome AS produto_nome, '
      'un.sigla AS unidade_sigla, un.fracionavel AS fracionavel, '
      'i.qtd_sistema AS qtd_sistema, i.qtd_contada AS qtd_contada, '
      'i.divergencia AS divergencia, '
      'i.justificativa AS justificativa_contagem, '
      'm.id AS ajuste_id, m.delta AS delta, m.saldo_apos AS saldo_apos, '
      'm.data_hora AS ajuste_data_hora, '
      'm.usuario_id AS ajuste_usuario_id, '
      'u.nome AS ajuste_usuario_nome, '
      'm.observacao AS justificativa_ajuste '
      'FROM itens_inventario i '
      'JOIN produtos p ON p.id = i.produto_id '
      'JOIN unidades un ON un.id = p.unidade_id AND un.contexto_id = p.contexto_id '
      "LEFT JOIN movimentacoes m ON m.inventario_id = i.inventario_id "
      "AND m.produto_id = i.produto_id AND m.contexto_id = i.contexto_id "
      "AND m.tipo = 'ajuste' "
      'LEFT JOIN usuarios u ON u.id = m.usuario_id AND u.contexto_id = m.contexto_id '
      'WHERE i.inventario_id = ? AND i.contexto_id = ? '
      'AND p.contexto_id = i.contexto_id '
      'ORDER BY p.nome COLLATE NOCASE, m.id',
      [inventarioId, contextoId],
    );
    return linhas.map(AuditoriaItemInventario.fromMap).toList();
  }

  Future<int> iniciar({required int usuarioId, String? observacao}) async {
    final db = await _obterBanco();
    return db.transaction<int>((txn) async {
      final contextoId = await ContextoTrabalhoRepository.exigirIdAtivo(txn);
      final abertos = await txn.rawQuery(
        "SELECT id FROM inventarios WHERE contexto_id = ? AND status = 'em_andamento' LIMIT 1",
        [contextoId],
      );
      if (abertos.isNotEmpty) {
        throw AppException(
          'Já existe um inventário em andamento. Finalize-o antes de iniciar outro.',
        );
      }
      final obs = observacao?.trim();
      return txn.insert('inventarios', {
        'data_hora': DateTime.now().toIso8601String(),
        'usuario_id': usuarioId,
        'status': 'em_andamento',
        'observacao': (obs == null || obs.isEmpty) ? null : obs,
        'contexto_id': contextoId,
      });
    });
  }

  Future<void> _exigirEmAndamento(
    DatabaseExecutor txn,
    int inventarioId,
    String contextoId,
  ) async {
    final ativo = await ContextoTrabalhoRepository.exigirIdAtivo(txn);
    if (ativo != contextoId) {
      throw AppException(
        ContextoTrabalhoRepository.mensagemContextoIndisponivel,
      );
    }
    final l = await txn.query(
      'inventarios',
      columns: ['status'],
      where: 'id = ? AND contexto_id = ?',
      whereArgs: [inventarioId, contextoId],
    );
    if (l.isEmpty) {
      throw AppException('Inventário não encontrado.');
    }
    if (l.first['status'] != 'em_andamento') {
      throw AppException('Este inventário já foi finalizado.');
    }
  }

  /// Registra ou atualiza a contagem de um produto. A justificativa é
  /// obrigatória quando há divergência.
  Future<void> registrarContagem({
    required int inventarioId,
    required int produtoId,
    required int qtdContada,
    String? justificativa,
  }) async {
    final db = await _obterBanco();
    await db.transaction((txn) async {
      final contextoId = await ContextoTrabalhoRepository.exigirIdAtivo(txn);
      await _exigirEmAndamento(txn, inventarioId, contextoId);
      final linhas = await txn.rawQuery(
        'SELECT p.saldo AS saldo, p.ativo AS ativo, un.fracionavel AS fracionavel '
        'FROM produtos p JOIN unidades un ON un.id = p.unidade_id AND un.contexto_id = p.contexto_id '
        'WHERE p.id = ? AND p.contexto_id = ?',
        [produtoId, contextoId],
      );
      if (linhas.isEmpty) {
        throw AppException('Produto não encontrado.');
      }
      if ((linhas.first['ativo'] as int) != 1) {
        throw AppException('Produto inativo não pode ser contado.');
      }
      final saldo = linhas.first['saldo'] as int;
      final fracionavel = (linhas.first['fracionavel'] as int) == 1;
      final divergencia = InventarioRegras.avaliarContagem(
        saldoAtual: saldo,
        qtdContada: qtdContada,
        fracionavel: fracionavel,
        justificativa: justificativa,
      );
      final just = justificativa?.trim();
      final valores = <String, Object?>{
        'qtd_sistema': saldo,
        'qtd_contada': qtdContada,
        'divergencia': divergencia,
        'justificativa': (divergencia == 0 || just == null || just.isEmpty)
            ? null
            : just,
        'ajustado': 0,
      };
      final existente = await txn.query(
        'itens_inventario',
        columns: ['id'],
        where: 'inventario_id = ? AND produto_id = ? AND contexto_id = ?',
        whereArgs: [inventarioId, produtoId, contextoId],
      );
      if (existente.isEmpty) {
        await txn.insert('itens_inventario', {
          'inventario_id': inventarioId,
          'produto_id': produtoId,
          'contexto_id': contextoId,
          ...valores,
        });
      } else {
        await txn.update(
          'itens_inventario',
          valores,
          where: 'id = ? AND contexto_id = ?',
          whereArgs: [existente.first['id'], contextoId],
        );
      }
    });
  }

  /// Remove uma contagem, somente enquanto o inventário está em andamento.
  Future<void> removerItem(int itemId) async {
    final db = await _obterBanco();
    await db.transaction((txn) async {
      final contextoId = await ContextoTrabalhoRepository.exigirIdAtivo(txn);
      final l = await txn.query(
        'itens_inventario',
        columns: ['inventario_id'],
        where: 'id = ? AND contexto_id = ?',
        whereArgs: [itemId, contextoId],
      );
      if (l.isEmpty) return;
      await _exigirEmAndamento(
        txn,
        l.first['inventario_id'] as int,
        contextoId,
      );
      await txn.delete(
        'itens_inventario',
        where: 'id = ? AND contexto_id = ?',
        whereArgs: [itemId, contextoId],
      );
    });
  }

  /// Lança os ajustes e finaliza o inventário, tudo na MESMA transação:
  /// se qualquer item falhar, nada é alterado.
  Future<ResultadoFinalizacao> finalizar({
    required int inventarioId,
    required int usuarioId,
  }) async {
    final db = await _obterBanco();
    return db.transaction<ResultadoFinalizacao>((txn) async {
      final contextoId = await ContextoTrabalhoRepository.exigirIdAtivo(txn);
      await _exigirEmAndamento(txn, inventarioId, contextoId);
      final itens = await txn.rawQuery(
        'SELECT i.id AS item_id, i.produto_id AS produto_id, '
        'i.qtd_contada AS qtd_contada, i.justificativa AS justificativa, '
        'p.nome AS nome, p.saldo AS saldo, p.ativo AS ativo, '
        'un.fracionavel AS fracionavel '
        'FROM itens_inventario i '
        'JOIN produtos p ON p.id = i.produto_id '
        'JOIN unidades un ON un.id = p.unidade_id AND un.contexto_id = p.contexto_id '
        'WHERE i.inventario_id = ? AND i.contexto_id = ? '
        'AND p.contexto_id = i.contexto_id ORDER BY p.nome COLLATE NOCASE',
        [inventarioId, contextoId],
      );
      final agora = DateTime.now().toIso8601String();
      var ajustados = 0;
      var semDivergencia = 0;

      for (final it in itens) {
        final produtoId = it['produto_id'] as int;
        final saldoAtual = it['saldo'] as int;
        final nome = it['nome'] as String;
        final just = it['justificativa'] as String?;
        final plano = InventarioRegras.planejarAjuste(
          nome: nome,
          ativo: (it['ativo'] as int) == 1,
          saldoAtual: saldoAtual,
          qtdContada: it['qtd_contada'] as int,
          fracionavel: (it['fracionavel'] as int) == 1,
          justificativa: just,
        );
        if (plano == null) {
          semDivergencia++;
          continue;
        }
        await txn.insert('movimentacoes', {
          'produto_id': produtoId,
          'tipo': 'ajuste',
          'finalidade': null,
          'delta': plano.delta,
          'saldo_apos': plano.saldoApos,
          'data_hora': agora,
          'usuario_id': usuarioId,
          'observacao': just!.trim(),
          'inventario_id': inventarioId,
          'contexto_id': contextoId,
        });
        final alterados = await txn.update(
          'produtos',
          {'saldo': plano.saldoApos},
          where: 'id = ? AND contexto_id = ? AND saldo = ?',
          whereArgs: [produtoId, contextoId, saldoAtual],
        );
        if (alterados != 1) {
          throw AppException(
            'O saldo de "$nome" mudou durante a finalização. Tente novamente.',
          );
        }
        await txn.update(
          'itens_inventario',
          {'ajustado': 1},
          where: 'id = ? AND contexto_id = ?',
          whereArgs: [it['item_id'], contextoId],
        );
        ajustados++;
      }

      await txn.update(
        'inventarios',
        {'status': 'finalizado'},
        where: 'id = ? AND contexto_id = ?',
        whereArgs: [inventarioId, contextoId],
      );
      return ResultadoFinalizacao(ajustados, semDivergencia);
    });
  }
}
