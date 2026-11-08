import 'package:sqflite/sqflite.dart';
import 'package:projeto_2/core/database/contexto_trabalho_repository.dart';
import 'package:projeto_2/features/historico/models/historico_filtro.dart';
import 'package:projeto_2/features/movimentacoes/models/movimentacao.dart';

class HistoricoItem {
  final Movimentacao movimentacao;
  final String produtoNome;
  final String unidadeSigla;
  final bool fracionavel;

  const HistoricoItem({
    required this.movimentacao,
    required this.produtoNome,
    required this.unidadeSigla,
    required this.fracionavel,
  });
}

class HistoricoPagina {
  final List<HistoricoItem> itens;
  final bool temMais;
  const HistoricoPagina(this.itens, this.temMais);
}

class HistoricoRepository {
  HistoricoRepository(this._obterBanco);

  final Future<Database> Function() _obterBanco;

  Future<HistoricoPagina> consultar(HistoricoFiltro filtro) async {
    final db = await _obterBanco();
    final contextoId = await ContextoTrabalhoRepository.exigirIdAtivo(db);
    final sql = filtro.paraSql();
    final where = sql.where.isEmpty
        ? 'WHERE m.contexto_id = ?'
        : '${sql.where} AND m.contexto_id = ?';
    final linhas = await db.rawQuery(
      'SELECT m.*, us.nome AS usuario_nome, p.nome AS produto_nome, '
      'un.sigla AS unidade_sigla, un.fracionavel AS fracionavel '
      'FROM movimentacoes m '
      'JOIN produtos p ON p.id = m.produto_id AND p.contexto_id = m.contexto_id '
      'JOIN unidades un ON un.id = p.unidade_id AND un.contexto_id = m.contexto_id '
      'JOIN usuarios us ON us.id = m.usuario_id AND us.contexto_id = m.contexto_id '
      '$where '
      'ORDER BY m.data_hora DESC, m.id DESC '
      'LIMIT ?',
      [...sql.args, contextoId, filtro.limite + 1],
    );
    final itens = linhas
        .take(filtro.limite)
        .map(
          (l) => HistoricoItem(
            movimentacao: Movimentacao.fromMap(l),
            produtoNome: l['produto_nome'] as String,
            unidadeSigla: l['unidade_sigla'] as String,
            fracionavel: (l['fracionavel'] as int) == 1,
          ),
        )
        .toList();
    return HistoricoPagina(itens, linhas.length > filtro.limite);
  }
}
