import 'package:flutter_test/flutter_test.dart';

import 'package:projeto_2/features/painel/models/painel_dados.dart';

void main() {
  group('PainelAtalho.intervalo', () {
    test('seteDias: hoje 2026-10-31 vai de 2026-10-25 a 2026-10-31', () {
      final hoje = DateTime(2026, 10, 31, 15, 30);
      final intervalo = PainelAtalho.seteDias.intervalo(hoje);
      expect(intervalo.inicio, DateTime(2026, 10, 25));
      expect(intervalo.fim, DateTime(2026, 10, 31));
    });

    test('trintaDias: hoje 2026-10-31 vai de 2026-10-02 a 2026-10-31', () {
      final hoje = DateTime(2026, 10, 31, 15, 30);
      final intervalo = PainelAtalho.trintaDias.intervalo(hoje);
      expect(intervalo.inicio, DateTime(2026, 10, 2));
      expect(intervalo.fim, DateTime(2026, 10, 31));
    });

    test('esteMes: hoje 2026-10-31 vai de 2026-10-01 a 2026-10-31', () {
      final hoje = DateTime(2026, 10, 31, 15, 30);
      final intervalo = PainelAtalho.esteMes.intervalo(hoje);
      expect(intervalo.inicio, DateTime(2026, 10, 1));
      expect(intervalo.fim, DateTime(2026, 10, 31));
    });

    test('seteDias: hoje 2026-03-03 começa em 2026-02-25', () {
      final hoje = DateTime(2026, 3, 3);
      final intervalo = PainelAtalho.seteDias.intervalo(hoje);
      expect(intervalo.inicio, DateTime(2026, 2, 25));
      expect(intervalo.fim, DateTime(2026, 3, 3));
    });
  });

  group('PainelCalculos.chaveDia', () {
    test('formata com zero à esquerda', () {
      expect(PainelCalculos.chaveDia(DateTime(2026, 3, 5)), '2026-03-05');
      expect(PainelCalculos.chaveDia(DateTime(2026, 10, 31)), '2026-10-31');
    });
  });

  group('PainelCalculos.preencherDias', () {
    test('7 dias em ordem, zeros onde não há registro e valores nos dias presentes', () {
      final intervalo = Intervalo(DateTime(2026, 10, 25), DateTime(2026, 10, 31));
      final contagem = <String, int>{
        '2026-10-25': 2,
        '2026-10-28': 5,
      };
      final dias = PainelCalculos.preencherDias(intervalo, contagem);

      expect(dias.length, 7);
      expect(
        dias.map((d) => d.dia).toList(),
        [
          DateTime(2026, 10, 25),
          DateTime(2026, 10, 26),
          DateTime(2026, 10, 27),
          DateTime(2026, 10, 28),
          DateTime(2026, 10, 29),
          DateTime(2026, 10, 30),
          DateTime(2026, 10, 31),
        ],
      );
      expect(dias[0].total, 2);
      expect(dias[1].total, 0);
      expect(dias[2].total, 0);
      expect(dias[3].total, 5);
      expect(dias[4].total, 0);
      expect(dias[5].total, 0);
      expect(dias[6].total, 0);
    });
  });
}