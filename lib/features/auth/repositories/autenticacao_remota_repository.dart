import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

enum EventoSessaoRemota {
  inicial,
  entrou,
  saiu,
  recuperacaoSenha,
  sessaoAtualizada,
  falhaConexao,
}

class EstadoSessaoRemota {
  const EstadoSessaoRemota({
    required this.evento,
    this.email,
    this.emailConfirmado = false,
  });

  final EventoSessaoRemota evento;
  final String? email;
  final bool emailConfirmado;

  bool get autenticado => email != null;
}

class AutenticacaoRemotaException implements Exception {
  const AutenticacaoRemotaException(this.mensagem);

  final String mensagem;

  @override
  String toString() => mensagem;
}

abstract interface class AutenticacaoRemotaRepository {
  EstadoSessaoRemota get estadoAtual;
  Stream<EstadoSessaoRemota> get eventos;

  Future<bool> cadastrar({required String email, required String senha});
  Future<void> entrar({required String email, required String senha});
  Future<void> reenviarConfirmacao(String email);
  Future<void> solicitarRecuperacao(String email);
  Future<void> definirNovaSenha(String senha);
  Future<void> sair();
}

class AutenticacaoRemotaRedirects {
  const AutenticacaoRemotaRedirects._();

  static const confirmarEmail =
      'estoqueuan://auth-callback/areas-compartilhadas?fluxo=email-confirmado';
  static const recuperarSenha =
      'estoqueuan://auth-callback/areas-compartilhadas?fluxo=nova-senha';
}

class SupabaseAutenticacaoRemotaRepository
    implements AutenticacaoRemotaRepository {
  SupabaseAutenticacaoRemotaRepository(this._auth);

  final GoTrueClient _auth;

  @override
  EstadoSessaoRemota get estadoAtual =>
      _estado(EventoSessaoRemota.inicial, _auth.currentUser);

  @override
  Stream<EstadoSessaoRemota> get eventos => _auth.onAuthStateChange
      .map(
        (estado) => _estado(_mapearEvento(estado.event), estado.session?.user),
      )
      .transform(
        StreamTransformer<EstadoSessaoRemota, EstadoSessaoRemota>.fromHandlers(
          handleError: (erro, stack, sink) {
            sink.add(
              _estado(EventoSessaoRemota.falhaConexao, _auth.currentUser),
            );
          },
        ),
      );

  @override
  Future<bool> cadastrar({required String email, required String senha}) async {
    try {
      final resposta = await _auth.signUp(
        email: email.trim(),
        password: senha,
        emailRedirectTo: AutenticacaoRemotaRedirects.confirmarEmail,
      );
      // Com confirmação habilitada, o Supabase retorna o usuário sem sessão.
      return resposta.user != null && resposta.session == null;
    } on AuthException catch (erro) {
      throw _traduzirErro(erro);
    } on SocketException {
      throw const AutenticacaoRemotaException(
        'Sem conexão. Verifique a internet e tente novamente.',
      );
    } on TimeoutException {
      throw const AutenticacaoRemotaException(
        'A conexão demorou demais. Tente novamente.',
      );
    }
  }

  @override
  Future<void> entrar({required String email, required String senha}) async {
    try {
      await _auth.signInWithPassword(email: email.trim(), password: senha);
    } on AuthException catch (erro) {
      throw _traduzirErro(erro);
    } on SocketException {
      throw const AutenticacaoRemotaException(
        'Sem conexão. Verifique a internet e tente novamente.',
      );
    } on TimeoutException {
      throw const AutenticacaoRemotaException(
        'A conexão demorou demais. Tente novamente.',
      );
    }
  }

  @override
  Future<void> reenviarConfirmacao(String email) async {
    try {
      await _auth.resend(
        type: OtpType.signup,
        email: email.trim(),
        emailRedirectTo: AutenticacaoRemotaRedirects.confirmarEmail,
      );
    } on AuthException catch (erro) {
      throw _traduzirErro(erro);
    } on SocketException {
      throw const AutenticacaoRemotaException(
        'Sem conexão. Verifique a internet e tente novamente.',
      );
    } on TimeoutException {
      throw const AutenticacaoRemotaException(
        'A conexão demorou demais. Tente novamente.',
      );
    }
  }

  @override
  Future<void> solicitarRecuperacao(String email) async {
    try {
      await _auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: AutenticacaoRemotaRedirects.recuperarSenha,
      );
    } on AuthException catch (erro) {
      throw _traduzirErro(erro);
    } on SocketException {
      throw const AutenticacaoRemotaException(
        'Sem conexão. Verifique a internet e tente novamente.',
      );
    } on TimeoutException {
      throw const AutenticacaoRemotaException(
        'A conexão demorou demais. Tente novamente.',
      );
    }
  }

  @override
  Future<void> definirNovaSenha(String senha) async {
    if (_auth.currentSession == null) {
      throw const AutenticacaoRemotaException(
        'O link de recuperação expirou. Solicite outro e-mail.',
      );
    }
    try {
      await _auth.updateUser(UserAttributes(password: senha));
    } on AuthException catch (erro) {
      throw _traduzirErro(erro);
    } on SocketException {
      throw const AutenticacaoRemotaException(
        'Sem conexão. Verifique a internet e tente novamente.',
      );
    } on TimeoutException {
      throw const AutenticacaoRemotaException(
        'A conexão demorou demais. Tente novamente.',
      );
    }
  }

  @override
  Future<void> sair() async {
    try {
      await _auth.signOut();
    } on AuthException catch (erro) {
      throw _traduzirErro(erro);
    } on SocketException {
      throw const AutenticacaoRemotaException(
        'Sem conexão. A sessão remota não pôde ser encerrada.',
      );
    } on TimeoutException {
      throw const AutenticacaoRemotaException(
        'A conexão demorou demais. Tente novamente.',
      );
    }
  }

  EstadoSessaoRemota _estado(EventoSessaoRemota evento, User? usuario) {
    return EstadoSessaoRemota(
      evento: evento,
      email: usuario?.email,
      emailConfirmado: usuario?.emailConfirmedAt != null,
    );
  }

  EventoSessaoRemota _mapearEvento(AuthChangeEvent evento) {
    return switch (evento) {
      AuthChangeEvent.signedIn => EventoSessaoRemota.entrou,
      AuthChangeEvent.signedOut => EventoSessaoRemota.saiu,
      AuthChangeEvent.passwordRecovery => EventoSessaoRemota.recuperacaoSenha,
      AuthChangeEvent.initialSession => EventoSessaoRemota.inicial,
      _ => EventoSessaoRemota.sessaoAtualizada,
    };
  }

  AutenticacaoRemotaException _traduzirErro(AuthException erro) {
    if (erro is AuthRetryableFetchException ||
        (erro.statusCode == null && erro.code == null)) {
      return const AutenticacaoRemotaException(
        'Sem conexão com o serviço. Verifique a internet e tente novamente.',
      );
    }
    final codigo = (erro.code ?? '').toLowerCase();
    final mensagem = erro.message.toLowerCase();
    if (erro.statusCode == '429' ||
        codigo.contains('rate') ||
        mensagem.contains('rate limit') ||
        mensagem.contains('too many requests')) {
      return const AutenticacaoRemotaException(
        'Muitas solicitações em pouco tempo. Aguarde alguns minutos e tente novamente.',
      );
    }
    if (codigo == 'email_not_confirmed' ||
        mensagem.contains('email not confirmed')) {
      return const AutenticacaoRemotaException(
        'Confirme seu e-mail antes de entrar. Você pode solicitar o reenvio da confirmação.',
      );
    }
    if (codigo == 'user_already_exists' ||
        mensagem.contains('already registered')) {
      return const AutenticacaoRemotaException(
        'Já existe uma conta com este e-mail.',
      );
    }
    if (codigo == 'weak_password' || mensagem.contains('weak password')) {
      return const AutenticacaoRemotaException(
        'A senha não atende aos requisitos configurados no serviço.',
      );
    }
    if (mensagem.contains('invalid login credentials')) {
      return const AutenticacaoRemotaException('E-mail ou senha incorretos.');
    }
    if (mensagem.contains('expired') || mensagem.contains('invalid token')) {
      return const AutenticacaoRemotaException(
        'O link expirou ou não é válido. Solicite um novo e-mail.',
      );
    }
    return const AutenticacaoRemotaException(
      'Não foi possível concluir a solicitação. Confira os dados e tente novamente.',
    );
  }
}
