import 'package:projeto_2/core/utils/quantidade_utils.dart';
import 'package:projeto_2/features/relatorios/models/relatorio_dados.dart';

class RelatorioCsv {
  RelatorioCsv._();

  static String estoque(List<LinhaEstoqueRelatorio> linhas) {
    final registros = <List<String>>[
      ['ID', 'Produto', 'Categoria', 'Saldo', 'Status'],
      for (final linha in linhas)
        [
          linha.produtoId.toString(),
          linha.produtoNome,
          linha.categoriaNome,
          '${QuantidadeUtils.format(linha.saldo, fracionavel: linha.fracionavel)} ${linha.unidadeSigla}',
          linha.ativo ? 'Ativo' : 'Inativo',
        ],
    ];
    return _codificar(registros);
  }

  static String movimentacoes(List<LinhaMovimentacaoRelatorio> linhas) {
    final registros = <List<String>>[
      [
        'Data e hora',
        'Produto',
        'Tipo',
        'Variação',
        'Saldo após',
        'Responsável',
        'Observação',
      ],
      for (final linha in linhas)
        [
          _dataHora(linha.dataHora),
          linha.produtoNome,
          linha.tipo,
          '${linha.delta > 0 ? '+' : ''}${QuantidadeUtils.format(linha.delta, fracionavel: linha.fracionavel)} ${linha.unidadeSigla}',
          '${QuantidadeUtils.format(linha.saldoApos, fracionavel: linha.fracionavel)} ${linha.unidadeSigla}',
          linha.usuarioNome,
          linha.observacao ?? '',
        ],
    ];
    return _codificar(registros);
  }

  static String _codificar(List<List<String>> registros) {
    String campo(String valor) {
      final escapado = valor.replaceAll('"', '""');
      if (escapado.contains(';') ||
          escapado.contains('"') ||
          escapado.contains('\n') ||
          escapado.contains('\r')) {
        return '"$escapado"';
      }
      return escapado;
    }

    return '\uFEFF${registros.map((l) => l.map(campo).join(';')).join('\r\n')}';
  }

  static String _dataHora(DateTime data) {
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(data.day)}/${dois(data.month)}/${data.year} '
        '${dois(data.hour)}:${dois(data.minute)}';
  }
}
