class Categoria {
  const Categoria({
    required this.id,
    required this.nome,
    required this.ativa,
  });

  final int id;
  final String nome;
  final bool ativa;

  factory Categoria.fromMap(Map<String, Object?> map) {
    return Categoria(
      id: map['id'] as int,
      nome: map['nome'] as String,
      ativa: (map['ativa'] as int) == 1,
    );
  }
}