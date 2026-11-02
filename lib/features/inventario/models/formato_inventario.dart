class FormatoInventario {
  FormatoInventario._();

  static String _dois(int n) => n.toString().padLeft(2, '0');

  static String data(DateTime d) =>
      '${_dois(d.day)}/${_dois(d.month)}/${d.year}';

  static String dataHora(DateTime d) =>
      '${data(d)} ${_dois(d.hour)}:${_dois(d.minute)}';
}
