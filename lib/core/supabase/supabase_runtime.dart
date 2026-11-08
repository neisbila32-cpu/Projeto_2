import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:projeto_2/core/supabase/supabase_config.dart';

enum SupabaseRuntimeStatus {
  offline,
  ready,
  invalidConfiguration,
  initializationFailed,
}

typedef SupabaseClientInitializer =
    Future<SupabaseClient> Function(SupabaseConfig config);

class SupabaseRuntime {
  const SupabaseRuntime._({required this.status, this.client, this.message});

  const SupabaseRuntime.offline()
    : this._(status: SupabaseRuntimeStatus.offline);

  final SupabaseRuntimeStatus status;
  final SupabaseClient? client;
  final String? message;

  bool get isAvailable => status == SupabaseRuntimeStatus.ready;

  static Future<SupabaseRuntime> initialize(
    SupabaseConfig config, {
    SupabaseClientInitializer? initializer,
  }) async {
    if (!config.hasAnyValue) return const SupabaseRuntime.offline();

    final validationError = config.validationError;
    if (validationError != null) {
      return SupabaseRuntime._(
        status: SupabaseRuntimeStatus.invalidConfiguration,
        message: validationError,
      );
    }

    try {
      final client = await (initializer ?? _initializeSupabase)(config);
      return SupabaseRuntime._(
        status: SupabaseRuntimeStatus.ready,
        client: client,
      );
    } catch (_) {
      return const SupabaseRuntime._(
        status: SupabaseRuntimeStatus.initializationFailed,
        message:
            'Não foi possível iniciar o Supabase. O modo individual continua disponível.',
      );
    }
  }

  static Future<SupabaseClient> _initializeSupabase(
    SupabaseConfig config,
  ) async {
    await Supabase.initialize(
      url: config.normalizedUrl,
      publishableKey: config.normalizedPublishableKey,
    );
    return Supabase.instance.client;
  }
}
