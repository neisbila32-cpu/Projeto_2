import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:projeto_2/core/routes/app_router.dart';
import 'package:projeto_2/core/supabase/supabase_providers.dart';
import 'package:projeto_2/core/theme/app_theme.dart';
import 'package:projeto_2/features/configuracoes/providers/tema_provider.dart';
import 'package:projeto_2/features/perfil/widgets/tamanho_texto_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A conexão opcional é inicializada em segundo plano; a interface local não espera a rede.
    ref.watch(supabaseRuntimeProvider);
    final router = ref.watch(routerProvider);
    final tema = ref.watch(temaProvider).value ?? ThemeMode.system;
    return MaterialApp.router(
      title: 'Estoque UAN',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: tema,
      routerConfig: router,
      builder: (_, child) =>
          TamanhoTextoApp(child: child ?? const SizedBox.shrink()),
    );
  }
}
