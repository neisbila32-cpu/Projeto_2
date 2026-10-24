import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:projeto_2/features/auth/providers/auth_providers.dart';
import 'package:projeto_2/features/auth/models/usuario.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuarioAsync = ref.watch(sessionProvider);

    if (usuarioAsync.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final usuario = usuarioAsync.value;
    final nome = usuario?.nome ?? '';
    final perfil = usuario?.isAdmin == true ? 'Administrador' : 'Operador';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estoque UAN'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () {
              ref.read(sessionProvider.notifier).sair();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Ol\u00e1, $nome!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text('Perfil: $perfil'),
            const SizedBox(height: 24),
            const Text('Telas do estoque em constru\u00e7\u00e3o'),
          ],
        ),
      ),
    );
  }
}
