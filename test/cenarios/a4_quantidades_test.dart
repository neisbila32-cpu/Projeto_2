import 'package:flutter_test/flutter_test.dart';

import 'package:projeto_2/core/utils/quantidade_utils.dart';

void main() {
  group('A4 Quantidades — QuantidadeUtils', () {
    // Cada caso: (entrada, fracionavel, comportamento esperado, observação)
    final casos = <Map<String, Object?>>[
      {'entrada': '1,5', 'fracionavel': true, 'esperado': 1500, 'observacao': 'vírgula decimal aceita'},
      {'entrada': '1.5', 'fracionavel': true, 'esperado': 1500, 'observacao': 'ponto decimal aceito'},
      {'entrada': '1,500', 'fracionavel': true, 'esperado': 1500, 'observacao': '3 casas decimais aceitas'},
      {'entrada': '1,5000', 'fracionavel': true, 'esperado': null, 'observacao': '4 casas — comportamento a confirmar'},
      {'entrada': '', 'fracionavel': true, 'esperado': null, 'observacao': 'vazio — esperado null ou exceção'},
      {'entrada': 'abc', 'fracionavel': true, 'esperado': null, 'observacao': 'texto — esperado null ou exceção'},
      {'entrada': '-2', 'fracionavel': true, 'esperado': null, 'observacao': 'negativo — comportamento a confirmar'},
      {'entrada': '0', 'fracionavel': true, 'esperado': 0, 'observacao': 'zero — esperado 0 ou null'},
      {'entrada': ' 3 ', 'fracionavel': true, 'esperado': 3000, 'observacao': 'com espaços — esperado 3 após trim'},
      {'entrada': '1.000,5', 'fracionavel': true, 'esperado': null, 'observacao': 'milhar com ponto + vírgula — comportamento a confirmar'},
      {'entrada': '2,5', 'fracionavel': false, 'esperado': null, 'observacao': 'contável com vírgula — esperado rejeitado (só inteiros)'},
      {'entrada': '9999999999', 'fracionavel': true, 'esperado': null, 'observacao': 'número enorme — comportamento a confirmar'},
    ];

    for (final c in casos) {
      test('"${c['entrada']}" (fracionavel=${c['fracionavel']})', () async {
        final entrada = c['entrada'] as String;
        final fracionavel = c['fracionavel'] as bool;
        final esperado = c['esperado'] as int?;
        dynamic resultado;
        String? erro;
        try {
          resultado = QuantidadeUtils.parse(entrada, fracionavel: fracionavel);
        } catch (e) {
          erro = e.toString();
        }
        // Registra comportamento observado (não falha por causa do valor observado)
        print(
          'A4: entrada="$entrada" fracionavel=$fracionavel => '
          'resultado=$resultado erro=$erro  [${c['observacao']}]',
        );
        if (esperado != null) {
          expect(resultado, esperado);
        }
      });
    }
  });
}
