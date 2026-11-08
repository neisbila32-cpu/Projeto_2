import 'package:sqflite/sqflite.dart';

import 'package:projeto_2/core/database/contexto_trabalho_repository.dart';
import 'package:projeto_2/features/relatorios/models/relatorio_dados.dart';

class RelatorioRepository {
  RelatorioRepository(this._obterBanco);

  final Future<Database> Function() _obterBanco;

  String _rotuloTipo(String tipo) => switch (tipo) {
    'entrada' => 'Entrada',
    'saida' => 'Saída',
    'perda' => 'Perda',
    'ajuste' => 'Ajuste',
    _ => tipo,
  };

  Future<List<LinhaEstoqueRelatorio>> consultarEstoque() async {
    final db = await _obterBanco();
    final contextoId = await ContextoTrabalhoRepository.exigirIdAtivo(db);
    final linhas = await db.rawQuery(
      'SELECT p.id AS produto_id, p.nome AS produto_nome, '
      'c.nome AS categoria_nome, u.sigla AS unidade_sigla, '
      'u.fracionavel AS fracionavel, p.saldo AS saldo, p.ativo AS ativo '
      'FROM produtos p '
      'JOIN categorias c ON c.id = p.categoria_id AND c.contexto_id = p.contexto_id '
      'JOIN unidades u ON u.id = p.unidade_id AND u.contexto_id = p.contexto_id '
      'WHERE p.contexto_id = ? '
      'ORDER BY p.ativo DESC, p.nome COLLATE NOCASE',
      [contextoId],
    );
    return linhas
        .map(
          (l) => LinhaEstoqueRelatorio(
            produtoId: l['produto_id'] as int,
            produtoNome: l['produto_nome'] as String,
            categoriaNome: l['categoria_nome'] as String,
            unidadeSigla: l['unidade_sigla'] as String,
            fracionavel: (l['fracionavel'] as int) == 1,
            saldo: l['saldo'] as int,
            ativo: (l['ativo'] as int) == 1,
          ),
        )
        .toList();
  }

  Future<List<LinhaMovimentacaoRelatorio>> consultarMovimentacoes({
    required DateTime inicio,
    required DateTime fim,
  }) async {
    final db = await _obterBanco();
    final contextoId = await ContextoTrabalhoRepository.exigirIdAtivo(db);
    final inicioDia = DateTime(inicio.year, inicio.month, inicio.day);
    final fimExclusivo = DateTime(fim.year, fim.month, fim.day + 1);
    final linhas = await db.rawQuery(
      'SELECT m.id AS movimentacao_id, m.data_hora AS data_hora, '
      'p.nome AS produto_nome, u.sigla AS unidade_sigla, '
      'u.fracionavel AS fracionavel, m.tipo AS tipo, m.delta AS delta, '
      'm.saldo_apos AS saldo_apos, us.nome AS usuario_nome, '
      'm.observacao AS observacao '
      'FROM movimentacoes m '
      'JOIN produtos p ON p.id = m.produto_id '
      'JOIN unidades u ON u.id = p.unidade_id AND u.contexto_id = m.contexto_id '
      'JOIN usuarios us ON us.id = m.usuario_id AND us.contexto_id = m.contexto_id '
      'WHERE m.contexto_id = ? AND p.contexto_id = m.contexto_id '
      'AND m.data_hora >= ? AND m.data_hora < ? '
      'ORDER BY m.data_hora DESC, m.id DESC',
      [contextoId, inicioDia.toIso8601String(), fimExclusivo.toIso8601String()],
    );
    return linhas
        .map(
          (l) => LinhaMovimentacaoRelatorio(
            id: l['movimentacao_id'] as int,
            dataHora: DateTime.parse(l['data_hora'] as String),
            produtoNome: l['produto_nome'] as String,
            unidadeSigla: l['unidade_sigla'] as String,
            fracionavel: (l['fracionavel'] as int) == 1,
            tipo: _rotuloTipo(l['tipo'] as String),
            delta: l['delta'] as int,
            saldoApos: l['saldo_apos'] as int,
            usuarioNome: l['usuario_nome'] as String,
            observacao: l['observacao'] as String?,
          ),
        )
        .toList();
  }
}
