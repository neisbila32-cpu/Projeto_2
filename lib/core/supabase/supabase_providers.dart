import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:projeto_2/core/supabase/supabase_config.dart';
import 'package:projeto_2/core/supabase/supabase_runtime.dart';

final supabaseRuntimeProvider = FutureProvider<SupabaseRuntime>((ref) {
  return SupabaseRuntime.initialize(SupabaseConfig.fromEnvironment());
});

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  return ref.watch(supabaseRuntimeProvider).value?.client;
});
