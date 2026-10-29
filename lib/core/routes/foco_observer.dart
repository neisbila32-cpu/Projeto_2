import 'package:flutter/material.dart';

/// Tira o foco de qualquer campo de texto ao voltar de uma tela, para o
/// teclado não reaparecer sozinho.
class FocoObserver extends NavigatorObserver {
  void _tirarFoco() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _tirarFoco();
  }
}