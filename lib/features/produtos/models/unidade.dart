class Unidade {
  const Unidade({
    required this.id,
    required this.sigla,
    required this.nome,
    required this.fracionavel,
    required this.ativa,
  });

  final int id;
  final String sigla;
  final String nome;
  final bool fracionavel;
  final bool ativa;

  String get rotulo => '$nome ($sigla)';

  factory Unidade.fromMap(Map<String, Object?> map) {
    return Unidade(
      id: map['id'] as int,
      sigla: map['sigla'] as String,
      nome: map['nome'] as String,
      fracionavel: (map['fracionavel'] as int) == 1,
      ativa: (map['ativa'] as int) == 1,
    );
  }
}