class Usuario {
  const Usuario({
    required this.id,
    required this.nome,
    required this.login,
    required this.perfil,
    required this.ativo,
  });

  final int id;
  final String nome;
  final String login;
  final String perfil; // 'admin' ou 'operador'
  final bool ativo;

  bool get isAdmin => perfil == 'admin';

  factory Usuario.fromMap(Map<String, Object?> map) {
    return Usuario(
      id: map['id'] as int,
      nome: map['nome'] as String,
      login: map['login'] as String,
      perfil: map['perfil'] as String,
      ativo: (map['ativo'] as int) == 1,
    );
  }
}
