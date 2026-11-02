import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:projeto_2/features/configuracoes/providers/tema_provider.dart';

class ConfiguracoesScreen extends ConsumerWidget {
  const ConfiguracoesScreen({super.key});

  Future<void> _definirTema(
      BuildContext context, WidgetRef ref, ThemeMode tema) async {
    try {
      await ref.read(temaProvider.notifier).definir(tema);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Não foi possível salvar a preferência de tema.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = ref.watch(temaProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aparência',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Escolha como o Estoque UAN será exibido neste aparelho.',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  tema.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (_, _) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Não foi possível carregar a preferência.'),
                        TextButton(
                          onPressed: () => ref.invalidate(temaProvider),
                          child: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                    data: (modo) => SegmentedButton<ThemeMode>(
                      multiSelectionEnabled: false,
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.settings_brightness_outlined),
                          label: Text('Sistema'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_outlined),
                          label: Text('Claro'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_outlined),
                          label: Text('Escuro'),
                        ),
                      ],
                      selected: {modo},
                      onSelectionChanged: (selecionados) {
                        if (selecionados.isNotEmpty) {
                          _definirTema(context, ref, selecionados.first);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
