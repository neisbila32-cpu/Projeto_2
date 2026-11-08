import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:projeto_2/core/supabase/supabase_providers.dart';

abstract interface class AutenticacaoRemota {
  GoTrueClient get cliente;
}

class SupabaseAutenticacaoRemota implements AutenticacaoRemota {
  const SupabaseAutenticacaoRemota(this._client);

  final SupabaseClient _client;

  @override
  GoTrueClient get cliente => _client.auth;
}

final autenticacaoRemotaProvider = Provider<AutenticacaoRemota?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseAutenticacaoRemota(client);
});
