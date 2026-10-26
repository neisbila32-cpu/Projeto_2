class TextoUtils {
  TextoUtils._();

  // áàâãä éèêë íìîï óòôõö úùûü ç ñ
  static const String _de =
      '\u00e1\u00e0\u00e2\u00e3\u00e4\u00e9\u00e8\u00ea\u00eb\u00ed\u00ec\u00ee\u00ef\u00f3\u00f2\u00f4\u00f5\u00f6\u00fa\u00f9\u00fb\u00fc\u00e7\u00f1';
  static const String _para = 'aaaaaeeeeiiiiooooouuuucn';

  /// Minúsculas, sem acentos e sem espaços nas pontas (para busca e comparação).
  static String normalizar(String texto) {
    final buffer = StringBuffer();
    for (final ch in texto.toLowerCase().split('')) {
      final i = _de.indexOf(ch);
      buffer.write(i >= 0 ? _para[i] : ch);
    }
    return buffer.toString().trim();
  }
}