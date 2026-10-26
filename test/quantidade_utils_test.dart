import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_2/core/utils/quantidade_utils.dart';
import 'package:projeto_2/core/utils/texto_utils.dart';

void main() {
  group('QuantidadeUtils.parse', () {
    test('fracionável aceita vírgula, ponto e até 3 casas', () {
      expect(QuantidadeUtils.parse('1,5', fracionavel: true), 1500);
      expect(QuantidadeUtils.parse('1.25', fracionavel: true), 1250);
      expect(QuantidadeUtils.parse('2', fracionavel: true), 2000);
      expect(QuantidadeUtils.parse('0,001', fracionavel: true), 1);
    });

    test('fracionável rejeita valores inválidos', () {
      expect(QuantidadeUtils.parse('1,2345', fracionavel: true), isNull);
      expect(QuantidadeUtils.parse('abc', fracionavel: true), isNull);
      expect(QuantidadeUtils.parse('-1', fracionavel: true), isNull);
      expect(QuantidadeUtils.parse('', fracionavel: true), isNull);
    });

    test('contável aceita apenas inteiros', () {
      expect(QuantidadeUtils.parse('12', fracionavel: false), 12000);
      expect(QuantidadeUtils.parse('1,5', fracionavel: false), isNull);
      expect(QuantidadeUtils.parse('2.0', fracionavel: false), isNull);
    });
  });

  group('QuantidadeUtils.format', () {
    test('fracionável remove zeros à direita e usa vírgula', () {
      expect(QuantidadeUtils.format(1500, fracionavel: true), '1,5');
      expect(QuantidadeUtils.format(2000, fracionavel: true), '2');
      expect(QuantidadeUtils.format(1234, fracionavel: true), '1,234');
      expect(QuantidadeUtils.format(0, fracionavel: true), '0');
      expect(QuantidadeUtils.format(-500, fracionavel: true), '-0,5');
    });

    test('contável mostra inteiro', () {
      expect(QuantidadeUtils.format(12000, fracionavel: false), '12');
    });
  });

  test('TextoUtils.normalizar ignora acentos e maiúsculas', () {
    expect(TextoUtils.normalizar('  A\u00e7\u00facar  '), 'acucar');
    expect(TextoUtils.normalizar('FEIJ\u00c3O'), 'feijao');
  });
}