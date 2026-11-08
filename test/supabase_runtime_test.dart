import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:projeto_2/core/supabase/supabase_config.dart';
import 'package:projeto_2/core/supabase/supabase_providers.dart';
import 'package:projeto_2/core/supabase/supabase_runtime.dart';
import 'package:projeto_2/features/auth/models/usuario.dart';
import 'package:projeto_2/features/auth/providers/auth_providers.dart';
import 'package:projeto_2/features/auth/providers/autenticacao_remota_provider.dart';

void main() {
  group('Configuração Supabase opcional', () {
    test('sem configurações permanece offline sem inicializar o SDK', () async {
      var inicializadorChamado = false;
      final runtime = await SupabaseRuntime.initialize(
        const SupabaseConfig(url: '', publishableKey: ''),
        initializer: (_) async {
          inicializadorChamado = true;
          throw StateError('Não deveria ser chamado');
        },
      );

      expect(runtime.status, SupabaseRuntimeStatus.offline);
      expect(runtime.client, isNull);
      expect(inicializadorChamado, isFalse);
    });

    test('lê URL e chave por configuração de ambiente sem expor a chave', () {
      final config = SupabaseConfig.fromEnvironment(
        url: 'https://uan-exemplo.supabase.co/',
        publishableKey: 'sb_publishable_chave_de_teste',
      );

      expect(config.normalizedUrl, 'https://uan-exemplo.supabase.co');
      expect(config.validationError, isNull);
      expect(config.toString(), isNot(contains(config.publishableKey)));
    });

    test('aceita uma inicialização válida usando cliente de teste', () async {
      final config = _configuracaoValida();
      SupabaseConfig? recebida;
      final runtime = await SupabaseRuntime.initialize(
        config,
        initializer: (valor) async {
          recebida = valor;
          return SupabaseClient(
            valor.normalizedUrl,
            valor.normalizedPublishableKey,
          );
        },
      );

      expect(runtime.status, SupabaseRuntimeStatus.ready);
      expect(runtime.isAvailable, isTrue);
      expect(runtime.client, isNotNull);
      expect(recebida, same(config));
    });

    test('falha do inicializador não impede o modo offline', () async {
      final runtime = await SupabaseRuntime.initialize(
        _configuracaoValida(),
        initializer: (_) async => throw StateError('Falha de teste'),
      );

      expect(runtime.status, SupabaseRuntimeStatus.initializationFailed);
      expect(runtime.client, isNull);
      expect(runtime.message, contains('modo individual'));
    });

    test(
      'rejeita configuração parcial, URL inválida e chave administrativa',
      () async {
        final configuracoesInvalidas = [
          const SupabaseConfig(
            url: 'https://uan.supabase.co',
            publishableKey: '',
          ),
          const SupabaseConfig(
            url: 'not-a-url',
            publishableKey: 'sb_publishable_chave_de_teste',
          ),
          const SupabaseConfig(
            url: 'http://servidor-remoto.exemplo',
            publishableKey: 'sb_publishable_chave_de_teste',
          ),
          const SupabaseConfig(
            url: 'https://uan.supabase.co',
            publishableKey: 'sb_secret_nao_permitida',
          ),
          SupabaseConfig(
            url: 'https://uan.supabase.co',
            publishableKey: _jwtComPapel('service_role'),
          ),
        ];

        for (final config in configuracoesInvalidas) {
          var inicializadorChamado = false;
          final runtime = await SupabaseRuntime.initialize(
            config,
            initializer: (_) async {
              inicializadorChamado = true;
              return SupabaseClient(
                'https://uan.supabase.co',
                'sb_publishable_chave_de_teste',
              );
            },
          );

          expect(runtime.status, SupabaseRuntimeStatus.invalidConfiguration);
          expect(runtime.client, isNull);
          expect(inicializadorChamado, isFalse);
        }
      },
    );

    test('chave anon JWT legada só é aceita com papel anon', () {
      final anon = SupabaseConfig(
        url: 'https://uan.supabase.co',
        publishableKey: _jwtComPapel('anon'),
      );
      final serviceRole = SupabaseConfig(
        url: 'https://uan.supabase.co',
        publishableKey: _jwtComPapel('service_role'),
      );

      expect(anon.validationError, isNull);
      expect(serviceRole.validationError, isNotNull);
    });

    test(
      'providers indisponíveis não alteram a sessão local existente',
      () async {
        final container = ProviderContainer(
          overrides: [
            supabaseRuntimeProvider.overrideWith(
              (ref) async => const SupabaseRuntime.offline(),
            ),
            sessionProvider.overrideWith(_SessaoLocalTeste.new),
          ],
        );
        addTearDown(container.dispose);

        await container.read(supabaseRuntimeProvider.future);
        expect(container.read(supabaseClientProvider), isNull);
        expect(container.read(autenticacaoRemotaProvider), isNull);
        expect(await container.read(sessionProvider.future), _usuarioLocal);
      },
    );

    test('provider de autenticação remoto usa o cliente configurado', () async {
      final runtime = await SupabaseRuntime.initialize(
        _configuracaoValida(),
        initializer: (config) async => SupabaseClient(
          config.normalizedUrl,
          config.normalizedPublishableKey,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          supabaseRuntimeProvider.overrideWith((ref) async => runtime),
        ],
      );
      addTearDown(container.dispose);

      await container.read(supabaseRuntimeProvider.future);
      expect(
        container.read(autenticacaoRemotaProvider),
        isA<AutenticacaoRemota>(),
      );
    });
  });
}

SupabaseConfig _configuracaoValida() => const SupabaseConfig(
  url: 'https://uan-teste.supabase.co',
  publishableKey: 'sb_publishable_chave_de_teste',
);

String _jwtComPapel(String role) {
  final payload = base64Url.encode(utf8.encode('{"role":"$role"}'));
  return 'header.${payload.replaceAll('=', '')}.signature';
}

const _usuarioLocal = Usuario(
  id: 1,
  nome: 'Usuária local',
  login: 'local',
  perfil: 'admin',
  ativo: true,
);

class _SessaoLocalTeste extends SessionController {
  @override
  Future<Usuario?> build() async => _usuarioLocal;
}
