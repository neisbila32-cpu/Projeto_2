import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:projeto_2/core/supabase/supabase_providers.dart';
import 'package:projeto_2/features/auth/repositories/autenticacao_remota_repository.dart';

final autenticacaoRemotaProvider = Provider<AutenticacaoRemotaRepository?>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  return client == null
      ? null
      : SupabaseAutenticacaoRemotaRepository(client.auth);
});

final estadoSessaoRemotaProvider = StreamProvider<EstadoSessaoRemota>((ref) {
  final autenticacao = ref.watch(autenticacaoRemotaProvider);
  if (autenticacao == null) {
    return Stream.value(
      const EstadoSessaoRemota(evento: EventoSessaoRemota.inicial),
    );
  }
  return autenticacao.eventos;
});
