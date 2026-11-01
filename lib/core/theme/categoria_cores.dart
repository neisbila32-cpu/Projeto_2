import 'package:flutter/material.dart';
import 'package:projeto_2/core/utils/texto_utils.dart';

/// Cor fixa de cada categoria, igual em todas as telas.
class CategoriaCores {
  CategoriaCores._();

  static const List<Color> _claro = [
    Color(0xFF2F7FBF), // 0 azul
    Color(0xFFD9825B), // 1 terracota
    Color(0xFFD9A43A), // 2 âmbar
    Color(0xFF4FA46E), // 3 verde
    Color(0xFF8A76C9), // 4 violeta
    Color(0xFF2FA3A0), // 5 turquesa
    Color(0xFFD56C93), // 6 rosa
    Color(0xFF7C8B99), // 7 cinza-azulado
  ];

  static const List<Color> _escuro = [
    Color(0xFF6FB0E6),
    Color(0xFFE7A27F),
    Color(0xFFE8BC62),
    Color(0xFF76C08F),
    Color(0xFFAD9BE0),
    Color(0xFF58C0BD),
    Color(0xFFE58FAE),
    Color(0xFF9AA8B5),
  ];

  static const Map<String, int> _fixas = {
    'proteinas': 1,
    'mercearia': 2,
    'laticinios e derivados': 0,
    'hortifrutigranjeiros': 3,
    'descartaveis e utensilios': 4,
    'material de limpeza': 5,
  };

  static int indice(String nome) {
    final chave = TextoUtils.normalizar(nome);
    final fixo = _fixas[chave];
    if (fixo != null) return fixo;
    var soma = 0;
    for (final r in chave.runes) {
      soma = (soma * 31 + r) & 0x7fffffff;
    }
    return soma % _claro.length;
  }

  static Color de(String nome, Brightness brilho) {
    final i = indice(nome);
    return brilho == Brightness.dark ? _escuro[i] : _claro[i];
  }
}