import 'package:sqflite/sqflite.dart';
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
      final linhas = await txn.rawQuery(
        'SELECT p.saldo AS saldo, p.ativo AS ativo, u.fracionavel AS fracionavel '
        'FROM produtos p JOIN unidades u ON u.id = p.unidade_id '
        'WHERE p.id = ?',
        [produtoId],
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
      });

      final alterados = await txn.update(
        'produtos',
        {'saldo': resultado.saldoApos},
        where: 'id = ? AND saldo = ?',
        whereArgs: [produtoId, saldoAtual],
      );
      if (alterados != 1) {
        throw AppException('O saldo do produto mudou. Tente novamente.');
      }
      return resultado;
    });
  }

  Future<List<Movimentacao>> ultimasDoProduto(int produtoId,
      {int limite = 10}) async {
    final db = await _obterBanco();
    final linhas = await db.rawQuery(
      'SELECT m.*, u.nome AS usuario_nome FROM movimentacoes m '
      'JOIN usuarios u ON u.id = m.usuario_id '
      'WHERE m.produto_id = ? ORDER BY m.data_hora DESC, m.id DESC LIMIT ?',
      [produtoId, limite],
    );
    return linhas.map(Movimentacao.fromMap).toList();
  }
}