import 'package:sqflite/sqflite.dart';
import 'package:projeto_2/features/painel/models/painel_dados.dart';

class PainelRepository {
  PainelRepository(this._obterBanco);

  final Future<Database> Function() _obterBanco;

  static const String _periodo = 'm.data_hora >= ? AND m.data_hora < ?';

  Future<PainelDados> carregar(Intervalo intervalo,
      {int limiteRanking = 10}) async {
    final db = await _obterBanco();
    final i = intervalo.inicio;
    final f = intervalo.fim;
    final args = <Object?>[
      DateTime(i.year, i.month, i.day).toIso8601String(),
      DateTime(f.year, f.month, f.day + 1).toIso8601String(),
    ];

    final tipos = await db.rawQuery(
      'SELECT m.tipo AS tipo, COUNT(*) AS total '
      'FROM movimentacoes m WHERE $_periodo GROUP BY m.tipo',
      args,
    );
    var entradas = 0;
    var saidas = 0;
    var perdas = 0;
    var ajustes = 0;
    for (final l in tipos) {
      final total = l['total'] as int;
      switch (l['tipo'] as String) {
        case 'entrada':
          entradas = total;
          break;
        case 'saida':
          saidas = total;
          break;
        case 'perda':
          perdas = total;
          break;
        case 'ajuste':
          ajustes = total;
          break;
      }
    }

    final categorias = await db.rawQuery(
      'SELECT c.nome AS nome, COUNT(*) AS total '
      'FROM movimentacoes m '
      'JOIN produtos p ON p.id = m.produto_id '
      'JOIN categorias c ON c.id = p.categoria_id '
      "WHERE m.tipo = 'saida' AND $_periodo "
      'GROUP BY c.id ORDER BY total DESC, c.nome COLLATE NOCASE LIMIT ?',
      [...args, limiteRanking],
    );

    final produtos = await db.rawQuery(
      'SELECT p.nome AS nome, un.sigla AS sigla, un.fracionavel AS fracionavel, '
      'c.nome AS categoria, COUNT(*) AS total, -SUM(m.delta) AS quantidade '
      'FROM movimentacoes m '
      'JOIN produtos p ON p.id = m.produto_id '
      'JOIN unidades un ON un.id = p.unidade_id '
      'JOIN categorias c ON c.id = p.categoria_id '
      "WHERE m.tipo = 'saida' AND $_periodo "
      'GROUP BY p.id '
      'ORDER BY total DESC, quantidade DESC, p.nome COLLATE NOCASE LIMIT ?',
      [...args, limiteRanking],
    );

    final dias = await db.rawQuery(
      'SELECT substr(m.data_hora, 1, 10) AS dia, COUNT(*) AS total '
      'FROM movimentacoes m WHERE $_periodo GROUP BY dia',
      args,
    );
    final contagem = <String, int>{
      for (final l in dias) l['dia'] as String: l['total'] as int,
    };

    return PainelDados(
      intervalo: intervalo,
      resumo: ResumoMovimentos(
        entradas: entradas,
        saidas: saidas,
        perdas: perdas,
        ajustes: ajustes,
      ),
      porCategoria: categorias
          .map((l) => ItemRanking(
                nome: l['nome'] as String,
                saidas: l['total'] as int,
                categoria: l['nome'] as String,
              ))
          .toList(),
      porProduto: produtos
          .map((l) => ItemRanking(
                nome: l['nome'] as String,
                saidas: l['total'] as int,
                categoria: l['categoria'] as String,
                quantidade: l['quantidade'] as int,
                unidadeSigla: l['sigla'] as String,
                fracionavel: (l['fracionavel'] as int) == 1,
              ))
          .toList(),
      porDia: PainelCalculos.preencherDias(intervalo, contagem),
    );
  }
}
