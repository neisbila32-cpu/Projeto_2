import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:projeto_2/core/database/app_database.dart';
import 'package:projeto_2/features/auth/models/usuario.dart';
import 'package:projeto_2/features/auth/repositories/usuario_repository.dart';

final usuarioRepositoryProvider = Provider<UsuarioRepository>((ref) {
  return UsuarioRepository(AppDatabase.instance);
});

final existeUsuarioProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.read(usuarioRepositoryProvider).existeAlgumUsuario();
});

class SessionController extends AsyncNotifier<Usuario?> {
  static const String _chave = 'usuario_logado_id';

  @override
  Future<Usuario?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_chave);
    if (id == null) return null;
    return ref.read(usuarioRepositoryProvider).buscarPorId(id);
  }

  Future<void> entrar({required String login, required String senha}) async {
    final usuario = await ref
        .read(usuarioRepositoryProvider)
        .autenticar(login: login, senha: senha);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_chave, usuario.id);
    state = AsyncData(usuario);
  }

  Future<void> sair() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chave);
    state = const AsyncData(null);
  }
}

final sessionProvider =
    AsyncNotifierProvider<SessionController, Usuario?>(SessionController.new);
