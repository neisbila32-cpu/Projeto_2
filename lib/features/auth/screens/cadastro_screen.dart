import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:projeto_2/features/auth/providers/auth_providers.dart';
import 'package:projeto_2/features/auth/repositories/usuario_repository.dart';
import 'package:projeto_2/features/auth/widgets/codigo_recuperacao_dialog.dart';

class CadastroScreen extends ConsumerStatefulWidget {
  const CadastroScreen({super.key});

  @override
  ConsumerState<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends ConsumerState<CadastroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _loginController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  bool _senhaVisivel = false;
  bool _confirmarSenhaVisivel = false;
  bool _carregando = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _loginController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  String? _validarNome(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Informe o nome.';
    }
    return null;
  }

  String? _validarLogin(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Informe o login.';
    }
    if (valor.trim().length < 3) {
      return 'O login deve ter pelo menos 3 caracteres.';
    }
    if (valor.contains(' ')) {
      return 'O login n\u00e3o pode ter espa\u00e7os.';
    }
    return null;
  }

  String? _validarSenha(String? valor) {
    if (valor == null || valor.isEmpty) {
      return 'Informe a senha.';
    }
    if (valor.length < 6) {
      return 'A senha deve ter pelo menos 6 caracteres.';
    }
    return null;
  }

  String? _validarConfirmarSenha(String? valor) {
    if (valor == null || valor.isEmpty) {
      return 'Confirme a senha.';
    }
    if (valor != _senhaController.text) {
      return 'As senhas n\u00e3o coincidem.';
    }
    return null;
  }

  Future<void> _cadastrar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _carregando = true);

    try {
      final codigo = await ref.read(usuarioRepositoryProvider).cadastrar(
        nome: _nomeController.text.trim(),
        login: _loginController.text.trim(),
        senha: _senhaController.text,
      );

      if (!mounted) return;

      if (codigo != null) {
        await mostrarCodigoRecuperacao(context, codigo);
        if (!mounted) return;
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Conta criada. Fa\u00e7a login.')),
          );
        }
      }

      ref.invalidate(existeUsuarioProvider);

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
        const SnackBar(content: Text('Erro inesperado. Tente novamente.')),
      );
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    final existeAsync = ref.watch(existeUsuarioProvider);
    final ehPrimeiro = existeAsync.value == false;

    final titulo = ehPrimeiro
        ? 'Criar conta do administrador'
        : 'Criar conta';

    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              titulo,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nomeController,
                    decoration: const InputDecoration(
                      labelText: 'Nome',
                    ),
                    validator: _validarNome,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _loginController,
                    decoration: const InputDecoration(
                      labelText: 'Login',
                    ),
                    validator: _validarLogin,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _senhaController,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _senhaVisivel ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setState(() => _senhaVisivel = !_senhaVisivel),
                      ),
                    ),
                    obscureText: !_senhaVisivel,
                    validator: _validarSenha,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmarSenhaController,
                    decoration: InputDecoration(
                      labelText: 'Confirmar senha',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _confirmarSenhaVisivel
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setState(() => _confirmarSenhaVisivel =
                                !_confirmarSenhaVisivel),
                      ),
                    ),
                    obscureText: !_confirmarSenhaVisivel,
                    validator: _validarConfirmarSenha,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _carregando ? null : _cadastrar,
                      child: _carregando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Criar conta'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('J\u00e1 tenho conta'),
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
