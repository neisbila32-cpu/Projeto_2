import 'package:flutter/material.dart';
import 'package:projeto_2/features/home/widgets/app_drawer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:projeto_2/features/auth/providers/auth_providers.dart';
import 'package:projeto_2/features/perfil/providers/tamanho_texto_provider.dart';

class PerfilScreen extends ConsumerWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuarioAsync = ref.watch(sessionProvider);
    final tamanhoTexto =
        ref.watch(tamanhoTextoProvider).value ?? TamanhoTexto.padrao;
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: drawerMenuButton(context),
        title: const Text('Meu perfil'),
      ),
      body: usuarioAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Não foi possível carregar o perfil.'),
              TextButton(
                onPressed: () => ref.invalidate(sessionProvider),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (usuario) {
          if (usuario == null) {
            return const Center(child: Text('Nenhum usuário está conectado.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        child: Text(
                          usuario.nome.isEmpty
                              ? '?'
                              : String.fromCharCode(
                                  usuario.nome.runes.first,
                                ).toUpperCase(),
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        usuario.nome,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(usuario.isAdmin ? 'Administrador' : 'Operador'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.alternate_email),
                      title: const Text('Login'),
                      subtitle: Text(usuario.login),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.verified_user_outlined),
                      title: const Text('Situação da conta'),
                      subtitle: Text(usuario.ativo ? 'Ativa' : 'Inativa'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Acessibilidade',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tamanho do texto em todo o aplicativo',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: TamanhoTexto.values.map((opcao) {
                          return ChoiceChip(
                            label: Text(
                              opcao.rotulo,
                              style: TextStyle(fontSize: 13 * opcao.fator),
                            ),
                            selected: tamanhoTexto == opcao,
                            onSelected: (selecionado) {
                              if (!selecionado) return;
                              ref
                                  .read(tamanhoTextoProvider.notifier)
                                  .definir(opcao)
                                  .catchError((_) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Não foi possível salvar o tamanho do texto.',
                                        ),
                                      ),
                                    );
                                  });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Os dados da conta são gerenciados localmente neste aparelho.',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
