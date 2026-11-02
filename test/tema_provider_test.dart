import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:projeto_2/features/configuracoes/providers/tema_provider.dart';

void main() {
  test('carrega o tema padrão do sistema e persiste a escolha', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(temaProvider.future), ThemeMode.system);
    await container.read(temaProvider.notifier).definir(ThemeMode.dark);

    expect(await container.read(temaProvider.future), ThemeMode.dark);
    final preferencias = await SharedPreferences.getInstance();
    expect(preferencias.getString('tema_aplicativo'), 'escuro');
  });

  test('lê preferência de tema já salva', () async {
    SharedPreferences.setMockInitialValues({'tema_aplicativo': 'claro'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(temaProvider.future), ThemeMode.light);
  });
}
