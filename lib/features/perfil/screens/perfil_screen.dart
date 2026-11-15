import 'package:flutter/material.dart';
import 'package:projeto_2/features/home/widgets/app_drawer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:projeto_2/features/auth/providers/auth_providers.dart';
import 'package:projeto_2/features/perfil/providers/tamanho_texto_provider.dart';

class PerfilScreen extends ConsumerStatefulWidget {
  const PerfilScreen({super.key});

  @override
  ConsumerState<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends ConsumerState<PerfilScreen> {
  double? _fatorEmEdicao;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final usuarioAsync = ref.watch(sessionProvider);
    final fatorSalvo =
        ref.watch(tamanhoTextoProvider).value ?? TamanhoTexto.padrao.fator;
    final fatorTexto = _fatorEmEdicao ?? fatorSalvo;
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
                        'Tamanho do texto em todo o aplicativo: '
                        '${(fatorTexto * 100).round()}%',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Slider(
                        min: 0.8,
                        max: 1.6,
                        divisions: 16,
                        value: fatorTexto,
                        label: '${(fatorTexto * 100).round()}%',
                        semanticFormatterCallback: (valor) =>
                            'Tamanho do texto: ${(valor * 100).round()} por cento',
                        onChanged: (valor) =>
                            setState(() => _fatorEmEdicao = valor),
                        onChangeEnd: (valor) async {
                          final mensageiro = ScaffoldMessenger.of(context);
                          try {
                            await ref
                                .read(tamanhoTextoProvider.notifier)
                                .definir(valor);
                            if (mounted) {
                              setState(() => _fatorEmEdicao = null);
                            }
                          } catch (_) {
                            if (!mounted) return;
                            setState(() => _fatorEmEdicao = null);
                            mensageiro.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Não foi possível salvar o tamanho do texto.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [Text('Menor'), Text('Maior')],
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
