import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TamanhoTexto {
  pequeno('Pequeno', 0.9, 'pequeno'),
  padrao('Padrão', 1.0, 'padrao'),
  grande('Grande', 1.15, 'grande'),
  muitoGrande('Muito grande', 1.3, 'muito_grande'),
  extraGrande('Extra grande', 1.5, 'extra_grande');

  const TamanhoTexto(this.rotulo, this.fator, this.valorSalvo);

  final String rotulo;
  final double fator;
  final String valorSalvo;

  static TamanhoTexto deValor(String? valor) => TamanhoTexto.values.firstWhere(
    (tamanho) => tamanho.valorSalvo == valor,
    orElse: () => TamanhoTexto.padrao,
  );
}

class TamanhoTextoController extends AsyncNotifier<TamanhoTexto> {
  static const String _chave = 'tamanho_texto_aplicativo';

  @override
  Future<TamanhoTexto> build() async {
    final preferencias = await SharedPreferences.getInstance();
    return TamanhoTexto.deValor(preferencias.getString(_chave));
  }

  Future<void> definir(TamanhoTexto tamanho) async {
    final anterior = state.value ?? TamanhoTexto.padrao;
    state = AsyncData(tamanho);
    try {
      final preferencias = await SharedPreferences.getInstance();
      final salvo = await preferencias.setString(_chave, tamanho.valorSalvo);
      if (!salvo) {
        throw StateError('Não foi possível salvar o tamanho do texto.');
      }
    } catch (_) {
      state = AsyncData(anterior);
      rethrow;
    }
  }
}

final tamanhoTextoProvider =
    AsyncNotifierProvider<TamanhoTextoController, TamanhoTexto>(
      TamanhoTextoController.new,
    );

/// Combina a preferência do app com o escalonamento configurado no Android.
class TamanhoTextoScaler extends TextScaler {
  const TamanhoTextoScaler(this.base, this.fator);

  final TextScaler base;
  final double fator;

  @override
  double scale(double fontSize) => base.scale(fontSize) * fator;

  @override
  double get textScaleFactor => scale(14) / 14;

  @override
  bool operator ==(Object other) =>
      other is TamanhoTextoScaler && other.base == base && other.fator == fator;

  @override
  int get hashCode => Object.hash(base, fator);
}
