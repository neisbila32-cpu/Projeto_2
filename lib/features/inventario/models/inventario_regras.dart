import 'package:projeto_2/core/utils/app_exception.dart';
import 'package:projeto_2/features/movimentacoes/models/movimentacao.dart';
import 'package:projeto_2/features/movimentacoes/models/movimentacao_regras.dart';

class InventarioRegras {
  /// Valida a contagem e devolve a divergência (contado menos saldo), em milésimos.
  static int avaliarContagem({
    required int saldoAtual,
    required int qtdContada,
    required bool fracionavel,
    String? justificativa,
  }) {
    if (qtdContada < 0) {
      throw AppException('A quantidade contada não pode ser negativa.');
    }
    if (!fracionavel && qtdContada % 1000 != 0) {
      throw AppException('Esta unidade aceita apenas quantidades inteiras.');
    }
    final divergencia = qtdContada - saldoAtual;
    if (divergencia != 0 && (justificativa?.trim().isEmpty ?? true)) {
      throw AppException('Informe a justificativa da divergência.');
    }
    return divergencia;
  }

  /// Planeja o ajuste na finalização. Devolve null quando o saldo atual já é
  /// igual ao contado (nada a ajustar). O novo saldo é SEMPRE a quantidade contada.
  static ResultadoMovimento? planejarAjuste({
    required String nome,
    required bool ativo,
    required int saldoAtual,
    required int qtdContada,
    required bool fracionavel,
    String? justificativa,
  }) {
    if (qtdContada == saldoAtual) return null;
    final just = justificativa?.trim() ?? '';
    if (just.isEmpty) {
      throw AppException('Informe a justificativa da divergência de "$nome".');
    }
    if (!ativo) {
      throw AppException(
          '"$nome" está inativo. Reative o produto ou remova-o da contagem.');
    }
    return MovimentacaoRegras.calcular(
      tipo: TipoMovimentacao.ajuste,
      saldoAtual: saldoAtual,
      valor: qtdContada,
      fracionavel: fracionavel,
      observacao: just,
    );
  }
}
