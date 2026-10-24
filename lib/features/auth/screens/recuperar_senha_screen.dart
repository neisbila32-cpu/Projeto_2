import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:projeto_2/features/auth/providers/auth_providers.dart';
import 'package:projeto_2/features/auth/repositories/usuario_repository.dart';
import 'package:projeto_2/features/auth/widgets/codigo_recuperacao_dialog.dart';

class RecuperarSenhaScreen extends ConsumerStatefulWidget {
  const RecuperarSenhaScreen({super.key});

  @override
  ConsumerState<RecuperarSenhaScreen> createState() =>
      _RecuperarSenhaScreenState();
}

class _RecuperarSenhaScreenState extends ConsumerState<RecuperarSenhaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _codigoController = TextEditingController();
  final _novaSenhaController = TextEditingController();
  final _confirmarNovaSenhaController = TextEditingController();
  bool _novaSenhaVisivel = false;
  bool _confirmarNovaSenhaVisivel = false;
  bool _carregando = false;

  @override
  void dispose() {
    _loginController.dispose();
    _codigoController.dispose();
    _novaSenhaController.dispose();
    _confirmarNovaSenhaController.dispose();
    super.dispose();
  }

  String? _validarLogin(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Informe o login do administrador.';
    }
    return null;
  }

  String? _validarCodigo(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Informe o c\u00f3digo de recupera\u00e7\u00e3o.';
    }
    return null;
  }

  String? _validarSenha(String? valor) {
    if (valor == null || valor.isEmpty) {
      return 'Informe a nova senha.';
    }
    if (valor.length < 6) {
      return 'A senha deve ter pelo menos 6 caracteres.';
    }
    return null;
  }

  String? _validarConfirmarSenha(String? valor) {
    if (valor == null || valor.isEmpty) {
      return 'Confirme a nova senha.';
    }
    if (valor != _novaSenhaController.text) {
      return 'As senhas n\u00e3o coincidem.';
    }
    return null;
  }

  Future<void> _redefinir() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _carregando = true);

    try {
      final novoCodigo = await ref
          .read(usuarioRepositoryProvider)
          .redefinirSenhaComCodigo(
            login: _loginController.text.trim(),
            codigo: _codigoController.text.trim(),
            novaSenha: _novaSenhaController.text,
          );

      if (!mounted) return;

      await mostrarCodigoRecuperacao(context, novoCodigo);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Senha redefinida. Fa\u00e7a login.')),
      );

      if (!mounted) return;
      context.go('/login');
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro inesperado. Tente novamente.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar senha')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'A recupera\u00e7\u00e3o por c\u00f3digo vale apenas para o '
              'administrador. Operadores devem pedir ao administrador para '
              'redefinir a senha.',
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _loginController,
                    decoration: const InputDecoration(
                      labelText: 'Login do administrador',
                    ),
                    validator: _validarLogin,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _codigoController,
                    decoration: const InputDecoration(
                      labelText: 'C\u00f3digo de recupera\u00e7\u00e3o',
                    ),
                    validator: _validarCodigo,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _novaSenhaController,
                    decoration: InputDecoration(
                      labelText: 'Nova senha',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _novaSenhaVisivel
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setState(() => _novaSenhaVisivel =
                                !_novaSenhaVisivel),
                      ),
                    ),
                    obscureText: !_novaSenhaVisivel,
                    validator: _validarSenha,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmarNovaSenhaController,
                    decoration: InputDecoration(
                      labelText: 'Confirmar nova senha',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _confirmarNovaSenhaVisivel
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setState(() => _confirmarNovaSenhaVisivel =
                                !_confirmarNovaSenhaVisivel),
                      ),
                    ),
                    obscureText: !_confirmarNovaSenhaVisivel,
                    validator: _validarConfirmarSenha,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _carregando ? null : _redefinir,
                      child: _carregando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Redefinir senha'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
