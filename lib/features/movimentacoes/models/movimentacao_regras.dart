import 'package:projeto_2/core/utils/app_exception.dart';
import 'package:projeto_2/features/movimentacoes/models/movimentacao.dart';

class ResultadoMovimento {
  final int delta; // em milésimos, com sinal
  final int saldoApos; // em milésimos
  const ResultadoMovimento(this.delta, this.saldoApos);
}

class MovimentacaoRegras {
  /// [valor] é a quantidade (entrada, saída, perda) ou o NOVO SALDO (ajuste),
  /// sempre em milésimos.
  static ResultadoMovimento calcular({
    required TipoMovimentacao tipo,
    required int saldoAtual,
    required int valor,
    required bool fracionavel,
    FinalidadeSaida? finalidade,
    String? observacao,
  }) {
    if (!fracionavel && valor % 1000 != 0) {
      throw AppException('Esta unidade aceita apenas quantidades inteiras.');
    }
    if (tipo == TipoMovimentacao.saida && finalidade == null) {
      throw AppException('Informe a finalidade da saída.');
    }
    final obs = observacao?.trim() ?? '';
    if ((tipo == TipoMovimentacao.perda || tipo == TipoMovimentacao.ajuste) &&
        obs.isEmpty) {
      throw AppException(tipo == TipoMovimentacao.perda
          ? 'Informe o motivo da perda.'
          : 'Informe a justificativa do ajuste.');
    }

    int delta;
    switch (tipo) {
      case TipoMovimentacao.entrada:
        if (valor <= 0) {
          throw AppException('Informe uma quantidade maior que zero.');
        }
        delta = valor;
        break;
      case TipoMovimentacao.saida:
      case TipoMovimentacao.perda:
        if (valor <= 0) {
          throw AppException('Informe uma quantidade maior que zero.');
        }
        delta = -valor;
        break;
      case TipoMovimentacao.ajuste:
        if (valor < 0) {
          throw AppException('O novo saldo não pode ser negativo.');
        }
        delta = valor - saldoAtual;
        if (delta == 0) {
          throw AppException(
              'O novo saldo é igual ao saldo atual. Nada a ajustar.');
        }
        break;
    }

    final saldoApos = saldoAtual + delta;
    if (saldoApos < 0) {
      throw AppException('Saldo insuficiente para esta operação.');
    }
    return ResultadoMovimento(delta, saldoApos);
  }
}