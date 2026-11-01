import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:projeto_2/core/theme/categoria_cores.dart';

void main() {
  test('a mesma categoria devolve sempre a mesma cor', () {
    final claro = CategoriaCores.de('Mercearia', Brightness.light);
    expect(CategoriaCores.de('Mercearia', Brightness.light), claro);
    final escuro = CategoriaCores.de('Mercearia', Brightness.dark);
    expect(CategoriaCores.de('Mercearia', Brightness.dark), escuro);
  });

  test('Proteínas, proteinas e PROTEÍNAS devolvem a mesma cor', () {
    final c1 = CategoriaCores.de('Proteínas', Brightness.light);
    final c2 = CategoriaCores.de('proteinas', Brightness.light);
    final c3 = CategoriaCores.de('PROTEÍNAS', Brightness.light);
    expect(c1, c2);
    expect(c1, c3);
    // índice fixo 1 (terracota claro)
    expect(c1, const Color(0xFFD9825B));
  });

  test('as 6 categorias do catálogo têm 6 cores diferentes', () {
    final categorias = [
      'Proteínas',
      'Mercearia',
      'Laticínios e derivados',
      'Hortifrutigranjeiros',
      'Descartáveis e utensílios',
      'Material de limpeza',
    ];
    final cores = categorias
        .map((c) => CategoriaCores.de(c, Brightness.light))
        .toList();
    for (var i = 0; i < cores.length; i++) {
      for (var j = i + 1; j < cores.length; j++) {
        expect(cores[i], isNot(cores[j]),
            reason: '$categorias[i] e $categorias[j] não podem ter a mesma cor');
      }
    }
  });

  test('a cor no tema escuro é diferente da do tema claro', () {
    for (final categoria in [
      'Proteínas',
      'Mercearia',
      'Laticínios e derivados',
      'Hortifrutigranjeiros',
      'Descartáveis e utensílios',
      'Material de limpeza',
      'Outra categoria qualquer',
    ]) {
      final claro = CategoriaCores.de(categoria, Brightness.light);
      final escuro = CategoriaCores.de(categoria, Brightness.dark);
      expect(claro, isNot(escuro),
          reason: 'tema claro e escuro devem diferir para $categoria');
    }
  });

  test('um nome desconhecido devolve sempre a mesma cor da paleta', () {
    final c1 = CategoriaCores.de('Categoria X', Brightness.light);
    final c2 = CategoriaCores.de('Categoria X', Brightness.light);
    expect(c1, c2);
    final indice = CategoriaCores.indice('Categoria X');
    expect(indice, greaterThanOrEqualTo(0));
    expect(indice, lessThanOrEqualTo(7));
  });
}