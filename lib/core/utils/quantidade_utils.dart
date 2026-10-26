/// Quantidades são guardadas como INTEIROS em milésimos (1,5 kg = 1500).
class QuantidadeUtils {
  QuantidadeUtils._();

  /// Converte o texto digitado em milésimos. Retorna null se for inválido.
  /// Aceita vírgula ou ponto. Unidade contável aceita só inteiros;
  /// fracionável aceita até 3 casas decimais.
  static int? parse(String texto, {required bool fracionavel}) {
    final t = texto.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;

    if (!fracionavel) {
      if (!RegExp(r'^\d{1,9}$').hasMatch(t)) return null;
      return int.parse(t) * 1000;
    }

    final m = RegExp(r'^(\d{1,9})(?:\.(\d{1,3}))?$').firstMatch(t);
    if (m == null) return null;
    final inteiro = int.parse(m.group(1)!);
    final frac = (m.group(2) ?? '').padRight(3, '0');
    return inteiro * 1000 + int.parse(frac);
  }

  /// Formata milésimos para exibição (ex.: 1500 -> "1,5"; 12000 contável -> "12").
  static String format(int milesimos, {required bool fracionavel}) {
    final negativo = milesimos < 0;
    final abs = milesimos.abs();
    String texto;
    if (!fracionavel) {
      texto = (abs / 1000).round().toString();
    } else {
      final inteiro = abs ~/ 1000;
      final frac = (abs % 1000)
          .toString()
          .padLeft(3, '0')
          .replaceFirst(RegExp(r'0+$'), '');
      texto = frac.isEmpty ? '$inteiro' : '$inteiro,$frac';
    }
    return negativo ? '-$texto' : texto;
  }
}