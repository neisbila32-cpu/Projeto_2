import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:projeto_2/core/routes/app_router.dart';
import 'package:projeto_2/features/auth/models/usuario.dart';
import 'package:projeto_2/features/auth/providers/auth_providers.dart';
import 'package:projeto_2/features/auth/providers/autenticacao_remota_provider.dart';
import 'package:projeto_2/features/auth/repositories/autenticacao_remota_repository.dart';
import 'package:projeto_2/features/auth/screens/areas_compartilhadas_screen.dart';

void main() {
  group('Autenticação remota por e-mail', () {
    test(
      'redirects Android are stable and distinct for email and recovery',
      () {
        final confirmacao = Uri.parse(
          AutenticacaoRemotaRedirects.confirmarEmail,
        );
        final recuperacao = Uri.parse(
          AutenticacaoRemotaRedirects.recuperarSenha,
        );

        expect(confirmacao.scheme, 'estoqueuan');
        expect(confirmacao.host, 'auth-callback');
        expect(confirmacao.path, '/areas-compartilhadas');
        expect(confirmacao.queryParameters['fluxo'], 'email-confirmado');
        expect(recuperacao.queryParameters['fluxo'], 'nova-senha');
      },
    );

    testWidgets('sem configuração informa que o modo individual continua', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            autenticacaoRemotaProvider.overrideWithValue(null),
            estadoSessaoRemotaProvider.overrideWith(
              (ref) => Stream.value(
                const EstadoSessaoRemota(evento: EventoSessaoRemota.inicial),
              ),
            ),
          ],
          child: const MaterialApp(home: AreasCompartilhadasScreen()),
        ),
      );

      expect(find.text('Áreas compartilhadas'), findsOneWidget);
      expect(find.text('Voltar ao modo individual'), findsOneWidget);
      expect(find.textContaining('continua disponível'), findsOneWidget);
    });

    testWidgets('valida e-mail, tamanho de senha e confirmação', (
      tester,
    ) async {
      final remoto = _AutenticacaoRemotaTeste();
      await _montarTela(tester, remoto);

      await tester.tap(find.text('Criar conta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Criar conta').last);
      await tester.pumpAndSettle();
      expect(find.text('Informe o e-mail.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('email-remoto')), 'invalido');
      await tester.enterText(find.byKey(const Key('senha-remota')), 'curta');
      await tester.enterText(
        find.byKey(const Key('confirmar-senha-remota')),
        'diferente',
      );
      await tester.tap(find.text('Criar conta').last);
      await tester.pumpAndSettle();

      expect(find.text('Informe um e-mail válido.'), findsOneWidget);
      expect(
        find.text('A senha deve ter pelo menos 8 caracteres.'),
        findsOneWidget,
      );
      expect(find.text('As senhas não coincidem.'), findsOneWidget);
      expect(remoto.cadastros, 0);
    });

    testWidgets('cadastro válido solicita confirmação de e-mail', (
      tester,
    ) async {
      final remoto = _AutenticacaoRemotaTeste()..precisaConfirmarEmail = true;
      await _montarTela(tester, remoto);

      await tester.tap(find.text('Criar conta'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('email-remoto')),
        'pessoa@exemplo.com',
      );
      await tester.enterText(
        find.byKey(const Key('senha-remota')),
        'senha-segura-123',
      );
      await tester.enterText(
        find.byKey(const Key('confirmar-senha-remota')),
        'senha-segura-123',
      );
      await tester.tap(find.text('Criar conta').last);
      await tester.pumpAndSettle();

      expect(remoto.cadastros, 1);
      expect(find.textContaining('link de confirmação'), findsOneWidget);
      expect(find.text('Entrar em uma conta compartilhada'), findsOneWidget);
    });

    testWidgets('login, logout e expiração acompanham eventos remotos', (
      tester,
    ) async {
      final remoto = _AutenticacaoRemotaTeste();
      await _montarTela(tester, remoto);

      await tester.enterText(
        find.byKey(const Key('email-remoto')),
        'pessoa@exemplo.com',
      );
      await tester.enterText(
        find.byKey(const Key('senha-remota')),
        'senha-segura-123',
      );
      await tester.tap(find.text('Entrar').first);
      await tester.pumpAndSettle();

      expect(remoto.logins, 1);
      expect(find.text('pessoa@exemplo.com'), findsOneWidget);

      remoto.emitir(const EstadoSessaoRemota(evento: EventoSessaoRemota.saiu));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('sessão remota foi encerrada'),
        findsOneWidget,
      );
      expect(find.text('Entrar em uma conta compartilhada'), findsOneWidget);
    });

    testWidgets('recuperação exige sessão e atualiza senha após callback', (
      tester,
    ) async {
      final remoto = _AutenticacaoRemotaTeste()
        ..estado = const EstadoSessaoRemota(
          evento: EventoSessaoRemota.recuperacaoSenha,
          email: 'pessoa@exemplo.com',
          emailConfirmado: true,
        );
      await _montarTela(tester, remoto, fluxoInicial: 'nova-senha');

      expect(find.text('Definir nova senha'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('senha-remota')),
        'nova-senha-segura',
      );
      await tester.enterText(
        find.byKey(const Key('confirmar-senha-remota')),
        'nova-senha-segura',
      );
      await tester.tap(find.text('Salvar nova senha'));
      await tester.pumpAndSettle();

      expect(remoto.senhasAtualizadas, 1);
      expect(find.textContaining('Senha atualizada'), findsOneWidget);
    });

    testWidgets('link expirado não altera a senha', (tester) async {
      final remoto = _AutenticacaoRemotaTeste();
      await _montarTela(tester, remoto, fluxoInicial: 'nova-senha');

      await tester.enterText(
        find.byKey(const Key('senha-remota')),
        'nova-senha-segura',
      );
      await tester.enterText(
        find.byKey(const Key('confirmar-senha-remota')),
        'nova-senha-segura',
      );
      await tester.tap(find.text('Salvar nova senha'));
      await tester.pumpAndSettle();

      expect(remoto.senhasAtualizadas, 0);
      expect(
        find.textContaining('link de recuperação expirou'),
        findsOneWidget,
      );
    });

    testWidgets('recuperação usa mensagem genérica e reenvio respeita limite', (
      tester,
    ) async {
      final remoto = _AutenticacaoRemotaTeste();
      await _montarTela(tester, remoto);
      await tester.tap(find.text('Esqueci minha senha'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('email-remoto')),
        'pessoa@exemplo.com',
      );
      await tester.tap(find.text('Enviar instruções'));
      await tester.pumpAndSettle();

      expect(remoto.recuperacoes, 1);
      expect(find.textContaining('Se houver uma conta'), findsOneWidget);
    });

    testWidgets('limite de reenvio e falha de rede mostram mensagens claras', (
      tester,
    ) async {
      final remoto = _AutenticacaoRemotaTeste()
        ..erroReenvio = const AutenticacaoRemotaException(
          'Muitas solicitações em pouco tempo. Aguarde alguns minutos e tente novamente.',
        );
      await _montarTela(tester, remoto);
      await tester.enterText(
        find.byKey(const Key('email-remoto')),
        'pessoa@exemplo.com',
      );
      await tester.tap(find.text('Reenviar confirmação de e-mail'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Muitas solicitações'), findsOneWidget);

      remoto.erroEntrar = const AutenticacaoRemotaException(
        'Sem conexão. Verifique a internet e tente novamente.',
      );
      await tester.enterText(
        find.byKey(const Key('senha-remota')),
        'senha-segura-123',
      );
      await tester.tap(find.text('Entrar').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Sem conexão'), findsOneWidget);
    });

    testWidgets('router encaminha recuperação ao formulário de nova senha', (
      tester,
    ) async {
      final remoto = _AutenticacaoRemotaTeste();
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(_SessaoLocalAusente.new),
          autenticacaoRemotaProvider.overrideWithValue(remoto),
          estadoSessaoRemotaProvider.overrideWith((ref) => remoto.eventos),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(routerProvider);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      router.go('/areas-compartilhadas');
      await tester.pumpAndSettle();
      remoto.emitir(
        const EstadoSessaoRemota(
          evento: EventoSessaoRemota.recuperacaoSenha,
          email: 'pessoa@exemplo.com',
          emailConfirmado: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        router.routeInformationProvider.value.uri.queryParameters['fluxo'],
        'nova-senha',
      );
      expect(find.text('Definir nova senha'), findsOneWidget);
    });

    testWidgets('retorno de confirmação apresenta o estado ao usuário', (
      tester,
    ) async {
      await _montarTela(
        tester,
        _AutenticacaoRemotaTeste(),
        fluxoInicial: 'email-confirmado',
      );

      expect(find.text('Áreas compartilhadas'), findsOneWidget);
      expect(find.textContaining('E-mail confirmado'), findsOneWidget);
    });
  });
}

Future<void> _montarTela(
  WidgetTester tester,
  _AutenticacaoRemotaTeste remoto, {
  String? fluxoInicial,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        autenticacaoRemotaProvider.overrideWithValue(remoto),
        estadoSessaoRemotaProvider.overrideWith((ref) => remoto.eventos),
      ],
      child: MaterialApp(
        home: AreasCompartilhadasScreen(fluxoInicial: fluxoInicial),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _AutenticacaoRemotaTeste implements AutenticacaoRemotaRepository {
  final _eventos = StreamController<EstadoSessaoRemota>.broadcast();
  EstadoSessaoRemota estado = const EstadoSessaoRemota(
    evento: EventoSessaoRemota.inicial,
  );
  bool precisaConfirmarEmail = false;
  AutenticacaoRemotaException? erroCadastro;
  AutenticacaoRemotaException? erroEntrar;
  AutenticacaoRemotaException? erroReenvio;
  int cadastros = 0;
  int logins = 0;
  int reenvios = 0;
  int recuperacoes = 0;
  int senhasAtualizadas = 0;

  @override
  EstadoSessaoRemota get estadoAtual => estado;

  @override
  Stream<EstadoSessaoRemota> get eventos => _eventos.stream;

  @override
  Future<bool> cadastrar({required String email, required String senha}) async {
    cadastros++;
    if (erroCadastro != null) throw erroCadastro!;
    return precisaConfirmarEmail;
  }

  @override
  Future<void> entrar({required String email, required String senha}) async {
    logins++;
    if (erroEntrar != null) throw erroEntrar!;
    emitir(
      EstadoSessaoRemota(
        evento: EventoSessaoRemota.entrou,
        email: email,
        emailConfirmado: true,
      ),
    );
  }

  @override
  Future<void> reenviarConfirmacao(String email) async {
    reenvios++;
    if (erroReenvio != null) throw erroReenvio!;
  }

  @override
  Future<void> solicitarRecuperacao(String email) async {
    recuperacoes++;
  }

  @override
  Future<void> definirNovaSenha(String senha) async {
    if (!estado.autenticado ||
        estado.evento != EventoSessaoRemota.recuperacaoSenha) {
      throw const AutenticacaoRemotaException(
        'O link de recuperação expirou. Solicite outro e-mail.',
      );
    }
    senhasAtualizadas++;
  }

  @override
  Future<void> sair() async {
    emitir(const EstadoSessaoRemota(evento: EventoSessaoRemota.saiu));
  }

  void emitir(EstadoSessaoRemota novoEstado) {
    estado = novoEstado;
    _eventos.add(novoEstado);
  }
}

class _SessaoLocalAusente extends SessionController {
  @override
  Future<Usuario?> build() async => null;
}
