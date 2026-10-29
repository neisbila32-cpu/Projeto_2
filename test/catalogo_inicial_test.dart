import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_2/core/utils/texto_utils.dart';
import 'package:projeto_2/features/produtos/data/catalogo_inicial.dart';

void main() {
  test('catalogoInicial tem exatamente 91 itens', () {
    expect(catalogoInicial.length, 91);
  });

  test('não há nomes duplicados após normalização', () {
    final normalizados =
        catalogoInicial.map((i) => TextoUtils.normalizar(i.nome)).toList();
    expect(normalizados.toSet().length, normalizados.length);
  });

  test('toda categoria usada está em categoriasCatalogo', () {
    final categoriasUsadas = catalogoInicial.map((i) => i.categoria).toSet();
    for (final c in categoriasUsadas) {
      expect(
        categoriasCatalogo.contains(c),
        isTrue,
        reason: '$c não está em categoriasCatalogo',
      );
    }
  });

  test('toda unidade usada está no conjunto esperado', () {
    const unidadesValidas = {
      'kg',
      'L',
      'un',
      'pct',
      'cx',
      'fardo',
      'lata',
      'bandeja',
      'fr',
    };
    final unidadesUsadas = catalogoInicial.map((i) => i.unidade).toSet();
    for (final u in unidadesUsadas) {
      expect(
        unidadesValidas.contains(u),
        isTrue,
        reason: '$u não está no conjunto válido',
      );
    }
  });
}