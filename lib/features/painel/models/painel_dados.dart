class Intervalo {
  final DateTime inicio; // dia inicial (inclusive)
  final DateTime fim; // dia final (inclusive)
  const Intervalo(this.inicio, this.fim);
}

enum PainelAtalho {
  seteDias('7 dias'),
  trintaDias('30 dias'),
  esteMes('Este mês');

  final String rotulo;
  const PainelAtalho(this.rotulo);

  Intervalo intervalo(DateTime agora) {
    final hoje = DateTime(agora.year, agora.month, agora.day);
    switch (this) {
      case PainelAtalho.seteDias:
        return Intervalo(DateTime(hoje.year, hoje.month, hoje.day - 6), hoje);
      case PainelAtalho.trintaDias:
        return Intervalo(DateTime(hoje.year, hoje.month, hoje.day - 29), hoje);
      case PainelAtalho.esteMes:
        return Intervalo(DateTime(hoje.year, hoje.month, 1), hoje);
    }
  }
}

class ResumoMovimentos {
  final int entradas;
  final int saidas;
  final int perdas;
  final int ajustes;

  const ResumoMovimentos({
    required this.entradas,
    required this.saidas,
    required this.perdas,
    required this.ajustes,
  });

  int get total => entradas + saidas + perdas + ajustes;
}

class ItemRanking {
  final String nome;
  final int saidas; // número de saídas registradas
  final int? quantidade; // milésimos, positiva; só no ranking de produtos
  final String? unidadeSigla;
  final bool fracionavel;

  const ItemRanking({
    required this.nome,
    required this.saidas,
    this.quantidade,
    this.unidadeSigla,
    this.fracionavel = false,
  });
}

class DiaMovimento {
  final DateTime dia;
  final int total;
  const DiaMovimento(this.dia, this.total);
}

class PainelDados {
  final Intervalo intervalo;
  final ResumoMovimentos resumo;
  final List<ItemRanking> porCategoria;
  final List<ItemRanking> porProduto;
  final List<DiaMovimento> porDia;

  const PainelDados({
    required this.intervalo,
    required this.resumo,
    required this.porCategoria,
    required this.porProduto,
    required this.porDia,
  });
}

class PainelCalculos {
  static String chaveDia(DateTime d) {
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${dois(d.month)}-${dois(d.day)}';
  }

  /// Uma entrada para CADA dia do intervalo, com 0 nos dias sem movimentação.
  static List<DiaMovimento> preencherDias(
      Intervalo intervalo, Map<String, int> contagem) {
    final dias = <DiaMovimento>[];
    var d = DateTime(
        intervalo.inicio.year, intervalo.inicio.month, intervalo.inicio.day);
    final fim = DateTime(
        intervalo.fim.year, intervalo.fim.month, intervalo.fim.day);
    while (!d.isAfter(fim)) {
      dias.add(DiaMovimento(d, contagem[chaveDia(d)] ?? 0));
      d = DateTime(d.year, d.month, d.day + 1);
    }
    return dias;
  }
}