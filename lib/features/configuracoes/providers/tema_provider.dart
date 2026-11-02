import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TemaController extends AsyncNotifier<ThemeMode> {
  static const String _chave = 'tema_aplicativo';

  @override
  Future<ThemeMode> build() async {
    final preferencias = await SharedPreferences.getInstance();
    return switch (preferencias.getString(_chave)) {
      'claro' => ThemeMode.light,
      'escuro' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> definir(ThemeMode tema) async {
    final anterior = state.value;
    state = AsyncData(tema);
    try {
      final preferencias = await SharedPreferences.getInstance();
      final valor = switch (tema) {
        ThemeMode.light => 'claro',
        ThemeMode.dark => 'escuro',
        ThemeMode.system => 'sistema',
      };
      final salvo = await preferencias.setString(_chave, valor);
      if (!salvo) throw StateError('Não foi possível salvar o tema.');
    } catch (_) {
      if (anterior != null) state = AsyncData(anterior);
      rethrow;
    }
  }
}

final temaProvider =
    AsyncNotifierProvider<TemaController, ThemeMode>(TemaController.new);
