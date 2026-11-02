import 'package:flutter/material.dart';
import 'package:projeto_2/features/home/widgets/app_drawer.dart';

class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});

  static const List<(IconData, String, String)> _etapas = [
    (
      Icons.inventory_2_outlined,
      'Cadastre os produtos',
      'Use o catálogo inicial ou cadastre produtos, categorias e unidades. '
          'Cada produto começa com saldo zero.',
    ),
    (
      Icons.add_shopping_cart_outlined,
      'Registre as movimentações',
      'Abra um produto para lançar entradas, saídas, perdas ou ajustes. '
          'Saídas precisam de finalidade e perdas e ajustes precisam de justificativa.',
    ),
    (
      Icons.fact_check_outlined,
      'Confira o estoque',
      'Consulte o painel, o histórico e os relatórios para acompanhar saldos '
          'e movimentações.',
    ),
    (
      Icons.playlist_add_check_circle_outlined,
      'Faça o inventário físico',
      'Conte os produtos, informe justificativas para divergências e finalize '
          'para ajustar os saldos à contagem.',
    ),
    (
      Icons.backup_outlined,
      'Proteja seus dados',
      'O banco fica neste aparelho. O administrador pode exportar um backup '
          'e restaurá-lo quando necessário.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: drawerMenuButton(context),
        title: const Text('Como usar o Estoque UAN'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Guia rápido', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Siga estas etapas para manter o estoque da unidade organizado.',
            style: TextStyle(color: cores.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < _etapas.length; i++)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: cores.primaryContainer,
                      foregroundColor: cores.onPrimaryContainer,
                      child: Icon(_etapas[i].$1),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${i + 1}. ${_etapas[i].$2}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(_etapas[i].$3),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'Lembrete: quantidades fracionáveis aceitam até três casas '
            'decimais; unidades contáveis aceitam apenas números inteiros.',
          ),
        ],
      ),
    );
  }
}
