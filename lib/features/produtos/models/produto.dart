import 'package:projeto_2/core/utils/quantidade_utils.dart';

class Produto {
  const Produto({
    required this.id,
    required this.nome,
    required this.categoriaId,
    required this.categoriaNome,
    required this.unidadeId,
    required this.unidadeSigla,
    required this.unidadeFracionavel,
    required this.saldo,
    required this.ativo,
  });

  final int id;
  final String nome;
  final int categoriaId;
  final String categoriaNome;
  final int unidadeId;
  final String unidadeSigla;
  final bool unidadeFracionavel;
  final int saldo; // em milésimos
  final bool ativo;

  /// Ex.: "1,5 kg" ou "12 pct".
  String get saldoFormatado =>
      '${QuantidadeUtils.format(saldo, fracionavel: unidadeFracionavel)} $unidadeSigla';

  factory Produto.fromMap(Map<String, Object?> map) {
    return Produto(
      id: map['id'] as int,
      nome: map['nome'] as String,
      categoriaId: map['categoria_id'] as int,
      categoriaNome: map['categoria_nome'] as String,
      unidadeId: map['unidade_id'] as int,
      unidadeSigla: map['unidade_sigla'] as String,
      unidadeFracionavel: (map['unidade_fracionavel'] as int) == 1,
      saldo: map['saldo'] as int,
      ativo: (map['ativo'] as int) == 1,
    );
  }
}