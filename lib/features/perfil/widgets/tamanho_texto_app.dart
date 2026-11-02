import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:projeto_2/features/perfil/providers/tamanho_texto_provider.dart';

/// Aplica a preferência tipográfica a toda a árvore do aplicativo.
class TamanhoTextoApp extends ConsumerWidget {
  const TamanhoTextoApp({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tamanho =
        ref.watch(tamanhoTextoProvider).value ?? TamanhoTexto.padrao;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TamanhoTextoScaler(
          MediaQuery.textScalerOf(context),
          tamanho.fator,
        ),
      ),
      child: child,
    );
  }
}
