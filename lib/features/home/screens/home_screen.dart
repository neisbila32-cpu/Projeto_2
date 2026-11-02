import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:projeto_2/features/auth/providers/auth_providers.dart';
import 'package:projeto_2/features/home/widgets/app_drawer.dart';
import 'package:projeto_2/features/produtos/widgets/produtos_lista_view.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuarioAsync = ref.watch(sessionProvider);

    if (usuarioAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final usuario = usuarioAsync.value;
    final nome = usuario?.nome ?? '';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: drawerMenuButton(context),
        title: const Text(
          'Estoque UAN',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: nome.isNotEmpty
                  ? Text(
                      nome[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: const ProdutosListaView(mostrarCategorias: false),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/produtos/novo'),
        icon: const Icon(Icons.add),
        label: const Text('Novo produto'),
      ),
    );
  }
}
