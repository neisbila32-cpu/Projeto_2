import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_2/core/utils/app_exception.dart';
import 'package:projeto_2/features/movimentacoes/models/movimentacao.dart';
import 'package:projeto_2/features/movimentacoes/models/movimentacao_regras.dart';

void main() {
  group('MovimentacaoRegras.calcular', () {
    test('entrada de 2500 com saldo 1000 (fracionavel): delta 2500, saldo 3500', () {
      final resultado = MovimentacaoRegras.calcular(
        tipo: TipoMovimentacao.entrada,
        saldoAtual: 1000,
        valor: 2500,
        fracionavel: true,
      );
      expect(resultado.delta, 2500);
      expect(resultado.saldoApos, 3500);
    });

    test('saida (finalidade producao) de 500 com saldo 1000: delta -500, saldo 500', () {
      final resultado = MovimentacaoRegras.calcular(
        tipo: TipoMovimentacao.saida,
        saldoAtual: 1000,
        valor: 500,
        fracionavel: true,
        finalidade: FinalidadeSaida.producao,
      );
      expect(resultado.delta, -500);
      expect(resultado.saldoApos, 500);
    });

    test('saida sem finalidade lança AppException', () {
      expect(
        () => MovimentacaoRegras.calcular(
          tipo: TipoMovimentacao.saida,
          saldoAtual: 1000,
          valor: 500,
          fracionavel: true,
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('saida maior que o saldo lança AppException', () {
      expect(
        () => MovimentacaoRegras.calcular(
          tipo: TipoMovimentacao.saida,
          saldoAtual: 1000,
          valor: 1500,
          fracionavel: true,
          finalidade: FinalidadeSaida.producao,
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('perda sem observacao lança AppException', () {
      expect(
        () => MovimentacaoRegras.calcular(
          tipo: TipoMovimentacao.perda,
          saldoAtual: 1000,
          valor: 200,
          fracionavel: true,
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('perda com observacao: delta negativo correto', () {
      final resultado = MovimentacaoRegras.calcular(
        tipo: TipoMovimentacao.perda,
        saldoAtual: 1000,
        valor: 300,
        fracionavel: true,
        observacao: 'Vencido',
      );
      expect(resultado.delta, -300);
      expect(resultado.saldoApos, 700);
    });

    test('ajuste para 3000 com saldo 1000 e justificativa: delta 2000, saldo 3000', () {
      final resultado = MovimentacaoRegras.calcular(
        tipo: TipoMovimentacao.ajuste,
        saldoAtual: 1000,
        valor: 3000,
        fracionavel: true,
        observacao: 'Contagem física conferiu a mais.',
      );
      expect(resultado.delta, 2000);
      expect(resultado.saldoApos, 3000);
    });
  });
}