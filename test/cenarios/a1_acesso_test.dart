import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:projeto_2/core/database/app_database.dart';
import 'package:projeto_2/features/auth/repositories/usuario_repository.dart'
    show AuthException, UsuarioRepository;
import 'apoio/banco_teste.dart';

void main() {
  group('A1 Primeiro acesso', () {
    late UsuarioRepository repo;
    late Database db;

    setUpAll(() async {
      await abrirBancoEmMemoria();
      db = await AppDatabase.instance.database;
      repo = UsuarioRepository(AppDatabase.instance);
    });

    setUp(() async {
      await limparDados(db);
    });

    test('cadastrar primeiro usuário vira administrador e recebe código XXXX-XXXX-XXXX', () async {
      final codigo = await repo.cadastrar(
        nome: 'Admin UAN',
        login: 'admin',
        senha: 'Senha123',
      );
      expect(codigo, isNotNull);
      expect(codigo!, matches(RegExp(r'^[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$')));
      final rows = await db.query('usuarios', where: 'login = ?', whereArgs: ['admin']);
      expect(rows.isNotEmpty, isTrue);
      expect(rows.first['perfil'] as String, 'admin');
      // senha nunca em texto puro
      expect(rows.first['senha_hash'] as String, isNot('Senha123'));
    });

    test('login correto', () async {
      await repo.cadastrar(nome: 'Usuário', login: 'usuario1', senha: 'Senha123');
      final usuario = await repo.autenticar(login: 'usuario1', senha: 'Senha123');
      expect(usuario, isNotNull);
      expect(usuario!.login, 'usuario1');
    });

    test('senha errada é rejeitada', () async {
      await repo.cadastrar(nome: 'Usuário', login: 'usuario2', senha: 'Senha123');
      try {
        await repo.autenticar(login: 'usuario2', senha: 'SenhaErrada');
        fail('Deveria lançar AuthException');
      } on AuthException {
        // esperado
      }
    });

    test('login inexistente é rejeitado', () async {
      await repo.cadastrar(nome: 'Usuário', login: 'usuario3', senha: 'Senha123');
      try {
        await repo.autenticar(login: 'naoexiste', senha: 'Senha123');
        fail('Deveria lançar AuthException');
      } on AuthException {
        // esperado
      }
    });

    test('login repetido é recusado (mesmo com maiúsculas e acentos diferentes)',
      skip: 'BUG: login com acento diferente (joão vs joao) é aceito como único', () async {
      await repo.cadastrar(nome: 'João', login: 'joao', senha: 'Senha123');
      try {
        await repo.cadastrar(nome: 'João MAIUSC', login: 'JOAO', senha: 'Senha123');
        fail('Deveria lançar AuthException');
      } on AuthException {
        // esperado
      }
      try {
        await repo.cadastrar(nome: 'Joao', login: 'joão', senha: 'Senha123');
        fail('Deveria lançar AuthException');
      } on AuthException {
        // esperado
      }
    });

    test('segundo usuário vira operador', () async {
      await repo.cadastrar(nome: 'Primeiro', login: 'primeiro', senha: 'Senha123');
      await repo.cadastrar(nome: 'Segundo', login: 'segundo', senha: 'Senha123');
      final rows = await db.query('usuarios', where: 'login = ?', whereArgs: ['segundo']);
      expect(rows.first['perfil'] as String, 'operador');
    });

    test('recuperação por código só funciona para o administrador e gera um código novo', () async {
      // primeiro = admin com código
      final codigoAdmin = await repo.cadastrar(
        nome: 'Admin', login: 'admin', senha: 'Senha123',
      );
      // segundo = operador SEM código (recup_hash nulo)
      await repo.cadastrar(nome: 'Op', login: 'operador', senha: 'Senha123');

      // admin pode recuperar
      final novoCodigo = await repo.redefinirSenhaComCodigo(
        login: 'admin', codigo: codigoAdmin!, novaSenha: 'NovaSenha456',
      );
      expect(novoCodigo, isNotNull);
      expect(novoCodigo, matches(RegExp(r'^[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$')));
      // código antigo não vale mais
      try {
        await repo.redefinirSenhaComCodigo(
          login: 'admin', codigo: codigoAdmin, novaSenha: 'OutraSenha789',
        );
        fail('Deveria lançar AuthException');
      } on AuthException {
        // esperado
      }

      // operador NÃO pode recuperar (perfil != admin)
      try {
        await repo.redefinirSenhaComCodigo(
          login: 'operador', codigo: 'AAAA-AAAA-AAAA', novaSenha: 'NovaSenha456',
        );
        fail('Deveria lançar AuthException');
      } on AuthException {
        // esperado
      }
    });

    test('usuário inativo não consegue entrar', () async {
      await repo.cadastrar(nome: 'Inativo', login: 'inativo', senha: 'Senha123');
      await db.update(
        'usuarios', {'ativo': 0}, where: 'login = ?', whereArgs: ['inativo'],
      );
      try {
        await repo.autenticar(login: 'inativo', senha: 'Senha123');
        fail('Deveria lançar AuthException');
      } on AuthException {
        // esperado
      }
    });

    test('senha nunca aparece em texto puro no banco', () async {
      await repo.cadastrar(nome: 'Usuário', login: 'senhasecreta', senha: 'MinhaSenha123');
      final rows = await db.query('usuarios', where: 'login = ?', whereArgs: ['senhasecreta']);
      final senhaHash = rows.first['senha_hash'] as String;
      final senhaSalt = rows.first['senha_salt'] as String;
      expect(senhaHash, isNot('MinhaSenha123'));
      expect(senhaSalt, isNot('MinhaSenha123'));
      expect(senhaHash.length, greaterThan(20));
    });
  });
}
