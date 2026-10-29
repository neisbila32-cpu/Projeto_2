import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:projeto_2/features/produtos/models/produto.dart';
import 'package:projeto_2/features/produtos/widgets/produtos_lista_view.dart';

class ProdutoSeletorScreen extends ConsumerWidget {
  const ProdutoSeletorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escolher produto')),
      body: ProdutosListaView(
        aoTocar: (produto) {
          context.push('/produtos/${produto.id}/movimentar');
        },
      ),
    );
  }
}