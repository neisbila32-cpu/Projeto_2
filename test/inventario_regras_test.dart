import 'package:flutter_test/flutter_test.dart';

import 'package:projeto_2/core/utils/app_exception.dart';
import 'package:projeto_2/features/inventario/models/inventario_regras.dart';

void main() {
  group('InventarioRegras.avaliarContagem', () {
    test('saldo igual não exige justificativa', () {
      expect(
        InventarioRegras.avaliarContagem(
          saldoAtual: 2000,
          qtdContada: 2000,
          fracionavel: true,
        ),
        0,
      );
    });

    test('devolve diferença positiva com justificativa', () {
      expect(
        InventarioRegras.avaliarContagem(
          saldoAtual: 2000,
          qtdContada: 3500,
          fracionavel: true,
          justificativa: 'Sobra na prateleira',
        ),
        1500,
      );
    });

    test('divergência sem justificativa lança AppException', () {
      expect(
        () => InventarioRegras.avaliarContagem(
          saldoAtual: 2000,
          qtdContada: 1000,
          fracionavel: true,
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('justificativa em branco lança AppException', () {
      expect(
        () => InventarioRegras.avaliarContagem(
          saldoAtual: 2000,
          qtdContada: 1000,
          fracionavel: true,
          justificativa: '   ',
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('quantidade negativa lança AppException', () {
      expect(
        () => InventarioRegras.avaliarContagem(
          saldoAtual: 0,
          qtdContada: -1,
          fracionavel: true,
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('unidade contável recusa fração e aceita inteiro', () {
      expect(
        () => InventarioRegras.avaliarContagem(
          saldoAtual: 0,
          qtdContada: 1500,
          fracionavel: false,
          justificativa: 'Contagem',
        ),
        throwsA(isA<AppException>()),
      );
      expect(
        InventarioRegras.avaliarContagem(
          saldoAtual: 0,
          qtdContada: 2000,
          fracionavel: false,
          justificativa: 'Contagem',
        ),
        2000,
      );
    });
  });

  group('InventarioRegras.planejarAjuste', () {
    test('saldo igual ao contado não planeja ajuste', () {
      expect(
        InventarioRegras.planejarAjuste(
          nome: 'Arroz',
          ativo: true,
          saldoAtual: 5000,
          qtdContada: 5000,
          fracionavel: true,
        ),
        isNull,
      );
    });

    test('planeja falta com novo saldo igual à contagem', () {
      final plano = InventarioRegras.planejarAjuste(
        nome: 'Arroz',
        ativo: true,
        saldoAtual: 5000,
        qtdContada: 3000,
        fracionavel: true,
        justificativa: 'Falta na prateleira',
      );
      expect(plano!.delta, -2000);
      expect(plano.saldoApos, 3000);
    });

    test('planeja contagem zero', () {
      final plano = InventarioRegras.planejarAjuste(
        nome: 'Arroz',
        ativo: true,
        saldoAtual: 5000,
        qtdContada: 0,
        fracionavel: true,
        justificativa: 'Produto não encontrado',
      );
      expect(plano!.delta, -5000);
      expect(plano.saldoApos, 0);
    });

    test('divergência sem justificativa lança AppException', () {
      expect(
        () => InventarioRegras.planejarAjuste(
          nome: 'Arroz',
          ativo: true,
          saldoAtual: 5000,
          qtdContada: 3000,
          fracionavel: true,
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('produto inativo lança com o nome na mensagem', () {
      expect(
        () => InventarioRegras.planejarAjuste(
          nome: 'Arroz integral',
          ativo: false,
          saldoAtual: 5000,
          qtdContada: 3000,
          fracionavel: true,
          justificativa: 'Diferença',
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            contains('Arroz integral'),
          ),
        ),
      );
    });

    test('unidade contável recusa quantidade fracionária', () {
      expect(
        () => InventarioRegras.planejarAjuste(
          nome: 'Caixa',
          ativo: true,
          saldoAtual: 2000,
          qtdContada: 1500,
          fracionavel: false,
          justificativa: 'Diferença',
        ),
        throwsA(isA<AppException>()),
      );
    });
  });
}
