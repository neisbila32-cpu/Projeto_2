import 'package:projeto_2/core/utils/quantidade_utils.dart';
import 'package:sqflite/sqflite.dart';
import 'package:projeto_2/core/database/contexto_trabalho_repository.dart';
import 'package:projeto_2/core/utils/app_exception.dart';
import 'package:projeto_2/features/movimentacoes/models/movimentacao.dart';
import 'package:projeto_2/features/movimentacoes/models/movimentacao_regras.dart';

class MovimentacaoRepository {
  MovimentacaoRepository(this._obterBanco);

  final Future<Database> Function() _obterBanco;

  /// Registra a movimentação e atualiza o saldo do produto na MESMA transação.
  /// [valor]: quantidade (entrada, saída, perda) ou novo saldo (ajuste),
  /// em milésimos.
  Future<ResultadoMovimento> registrar({
    required int produtoId,
    required TipoMovimentacao tipo,
    required int valor,
    required int usuarioId,
    FinalidadeSaida? finalidade,
    String? observacao,
    int? inventarioId,
  }) async {
    final db = await _obterBanco();
    return db.transaction<ResultadoMovimento>((txn) async {
      final contextoId = await ContextoTrabalhoRepository.exigirIdAtivo(txn);
      final linhas = await txn.rawQuery(
        'SELECT p.saldo AS saldo, p.ativo AS ativo, u.fracionavel AS fracionavel '
        'FROM produtos p JOIN unidades u ON u.id = p.unidade_id '
        'AND u.contexto_id = p.contexto_id '
        'WHERE p.id = ? AND p.contexto_id = ?',
        [produtoId, contextoId],
      );
      if (linhas.isEmpty) {
        throw AppException('Produto não encontrado.');
      }
      final linha = linhas.first;
      if ((linha['ativo'] as int) != 1) {
        throw AppException('Produto inativo não pode ser movimentado.');
      }
      final saldoAtual = linha['saldo'] as int;
      final fracionavel = (linha['fracionavel'] as int) == 1;

      final resultado = MovimentacaoRegras.calcular(
        tipo: tipo,
        saldoAtual: saldoAtual,
        valor: valor,
        fracionavel: fracionavel,
        finalidade: finalidade,
        observacao: observacao,
      );

      final obs = observacao?.trim();
      await txn.insert('movimentacoes', {
        'produto_id': produtoId,
        'tipo': tipo.valor,
        'finalidade': tipo == TipoMovimentacao.saida ? finalidade!.valor : null,
        'delta': resultado.delta,
        'saldo_apos': resultado.saldoApos,
        'data_hora': DateTime.now().toIso8601String(),
        'usuario_id': usuarioId,
        'observacao': (obs == null || obs.isEmpty) ? null : obs,
        'inventario_id': inventarioId,
        'contexto_id': contextoId,
      });

      final alterados = await txn.update(
        'produtos',
        {'saldo': resultado.saldoApos},
        where: 'id = ? AND contexto_id = ? AND saldo = ?',
        whereArgs: [produtoId, contextoId, saldoAtual],
      );
      if (alterados != 1) {
        throw AppException('O saldo do produto mudou. Tente novamente.');
      }
      return resultado;
    });
  }

  Future<int> quantidadeEfetiva(int id) async {
    final db = await _obterBanco();
    final contexto = await ContextoTrabalhoRepository.exigirIdAtivo(db);
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE((SELECT quantidade_corrigida FROM movimentacoes
        WHERE origem_id=m.id AND contexto_id=m.contexto_id ORDER BY id DESC LIMIT 1),
        ABS(m.delta)) AS quantidade FROM movimentacoes m WHERE id=? AND contexto_id=?
    ''',
      [id, contexto],
    );
    if (rows.isEmpty) throw AppException('Movimentação não encontrada.');
    return rows.single['quantidade'] as int;
  }

  static const _vinculosRetificacao = '''
        JOIN produtos p ON p.id=m.produto_id AND p.contexto_id=m.contexto_id AND p.ativo=1
        JOIN unidades u ON u.id=p.unidade_id AND u.contexto_id=m.contexto_id
        JOIN usuarios a ON a.id=? AND a.contexto_id=m.contexto_id AND a.ativo=1
  ''';

  static const _registroRetificavel = '''
    m.inventario_id IS NULL AND m.tipo IN ('entrada','saida') AND (a.perfil='admin' OR m.usuario_id=a.id)
  ''';

  static const _impedimentoRetificacao = '''
    EXISTS (
      SELECT 1 FROM itens_inventario x JOIN inventarios i ON i.id=x.inventario_id
      WHERE x.produto_id=m.produto_id AND x.contexto_id=m.contexto_id AND
        (i.status='em_andamento' OR i.finalizado_em IS NULL OR i.finalizado_em>=m.data_hora)
    ) OR EXISTS (
      SELECT 1 FROM movimentacoes posterior
      WHERE posterior.produto_id=m.produto_id AND posterior.contexto_id=m.contexto_id
        AND posterior.id>m.id AND posterior.tipo='ajuste' AND posterior.origem_id IS NULL
    )
  ''';

  Future<Set<int>> retificaveisDoProduto(int produtoId, int usuarioId) async {
    final db = await _obterBanco();
    final contexto = await ContextoTrabalhoRepository.exigirIdAtivo(db);
    final linhas = await db.rawQuery(
      '''
      SELECT m.id FROM (
        SELECT * FROM movimentacoes WHERE produto_id=? AND contexto_id=?
        ORDER BY data_hora DESC, id DESC LIMIT 10
      ) m
      $_vinculosRetificacao
      WHERE $_registroRetificavel AND NOT ($_impedimentoRetificacao)
    ''',
      [produtoId, contexto, usuarioId],
    );
    return linhas.map((linha) => linha['id'] as int).toSet();
  }

  Future<void> retificar({
    required int id,
    required int usuarioId,
    required int anterior,
    required int nova,
  }) async {
    final db = await _obterBanco();
    await db.transaction((txn) async {
      final contexto = await ContextoTrabalhoRepository.exigirIdAtivo(txn);
      final rows = await txn.rawQuery(
        '''
        SELECT m.*, p.saldo, u.fracionavel, ($_impedimentoRetificacao) AS impedido
        FROM movimentacoes m
        $_vinculosRetificacao
        WHERE m.id=? AND m.contexto_id=? AND $_registroRetificavel
      ''',
        [usuarioId, id, contexto],
      );
      if (rows.isEmpty) {
        throw AppException('Movimentação indisponível para correção.');
      }
      final m = rows.single;
      final produto = m['produto_id'];
      final ultimas = await txn.query(
        'movimentacoes',
        columns: ['quantidade_corrigida'],
        where: 'origem_id=? AND contexto_id=?',
        whereArgs: [id, contexto],
        orderBy: 'id DESC',
        limit: 1,
      );
      final atual = ultimas.isEmpty
          ? (m['delta'] as int).abs()
          : ultimas.single['quantidade_corrigida'];
      if (atual != anterior) {
        throw AppException('A quantidade mudou. Reabra a edição.');
      }
      if (nova <= 0 ||
          nova > 999999999999 ||
          nova == anterior ||
          (m['fracionavel'] == 0 && nova % 1000 != 0)) {
        throw AppException(
          'Informe uma nova quantidade válida e diferente da anterior.',
        );
      }
      if (m['impedido'] == 1) {
        throw AppException(
          'Há uma contagem ou ajuste posterior incompatível com esta correção.',
        );
      }
      final delta = (nova - anterior) * (m['tipo'] == 'entrada' ? 1 : -1);
      final saldo = (m['saldo'] as int) + delta;
      if (saldo < 0) {
        throw AppException('A correção deixaria o saldo negativo.');
      }
      await txn.insert('movimentacoes', {
        'tipo': 'ajuste',
        'origem_id': id,
        'quantidade_anterior': anterior,
        'quantidade_corrigida': nova,
        'produto_id': produto,
        'usuario_id': usuarioId,
        'contexto_id': contexto,
        'delta': delta,
        'saldo_apos': saldo,
        'data_hora': DateTime.now().toIso8601String(),
        'observacao':
            'Retificação da movimentação #$id: ${QuantidadeUtils.format(anterior, fracionavel: true)} → ${QuantidadeUtils.format(nova, fracionavel: true)}.',
      });
      await txn.update(
        'produtos',
        {'saldo': saldo},
        where: 'id=? AND contexto_id=?',
        whereArgs: [produto, contexto],
      );
    });
  }

  Future<List<Movimentacao>> ultimasDoProduto(
    int produtoId, {
    int limite = 10,
  }) async {
    final db = await _obterBanco();
    final contextoId = await ContextoTrabalhoRepository.exigirIdAtivo(db);
    final linhas = await db.rawQuery(
      'SELECT m.*, u.nome AS usuario_nome FROM movimentacoes m '
      'JOIN usuarios u ON u.id = m.usuario_id '
      'AND u.contexto_id = m.contexto_id '
      'WHERE m.produto_id = ? AND m.contexto_id = ? '
      'ORDER BY m.data_hora DESC, m.id DESC LIMIT ?',
      [produtoId, contextoId, limite],
    );
    return linhas.map(Movimentacao.fromMap).toList();
  }
}
