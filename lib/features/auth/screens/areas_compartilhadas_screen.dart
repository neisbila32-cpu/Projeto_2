import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:projeto_2/features/auth/providers/auth_providers.dart';
import 'package:projeto_2/features/auth/providers/autenticacao_remota_provider.dart';
import 'package:projeto_2/features/auth/repositories/autenticacao_remota_repository.dart';

enum _ModoAutenticacaoRemota { entrar, cadastrar, recuperar, novaSenha }

class AreasCompartilhadasScreen extends ConsumerStatefulWidget {
  const AreasCompartilhadasScreen({super.key, this.fluxoInicial});

  final String? fluxoInicial;

  @override
  ConsumerState<AreasCompartilhadasScreen> createState() =>
      _AreasCompartilhadasScreenState();
}

class _AreasCompartilhadasScreenState
    extends ConsumerState<AreasCompartilhadasScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  _ModoAutenticacaoRemota _modo = _ModoAutenticacaoRemota.entrar;
  bool _carregando = false;
  bool _mostrarSenha = false;
  bool _mostrarConfirmacao = false;
  bool _tinhaSessao = false;
  String? _mensagem;
  bool _mensagemErro = false;

  @override
  void initState() {
    super.initState();
    if (widget.fluxoInicial == 'nova-senha') {
      _modo = _ModoAutenticacaoRemota.novaSenha;
      _mensagem = 'Defina uma nova senha para sua conta compartilhada.';
    } else if (widget.fluxoInicial == 'email-confirmado') {
      _mensagem = 'E-mail confirmado. Você já pode entrar na sua conta.';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  String? _validarEmail(String? valor) {
    final email = valor?.trim() ?? '';
    if (email.isEmpty) return 'Informe o e-mail.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Informe um e-mail válido.';
    }
    return null;
  }

  String? _validarSenha(String? valor) {
    if (valor == null || valor.isEmpty) return 'Informe a senha.';
    if (valor.length < 8) return 'A senha deve ter pelo menos 8 caracteres.';
    return null;
  }

  String? _validarConfirmacao(String? valor) {
    if (valor == null || valor.isEmpty) return 'Confirme a senha.';
    if (valor != _senhaController.text) return 'As senhas não coincidem.';
    return null;
  }

  Future<void> _executar(Future<void> Function() operacao) async {
    setState(() {
      _carregando = true;
      _mensagem = null;
    });
    try {
      await operacao();
    } on AutenticacaoRemotaException catch (erro) {
      _definirMensagem(erro.mensagem, erro: true);
    } catch (_) {
      _definirMensagem(
        'Não foi possível concluir a solicitação. Verifique a conexão e tente novamente.',
        erro: true,
      );
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _definirMensagem(String mensagem, {bool erro = false}) {
    if (!mounted) return;
    setState(() {
      _mensagem = mensagem;
      _mensagemErro = erro;
    });
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    final remoto = ref.read(autenticacaoRemotaProvider);
    if (remoto == null) return;
    final email = _emailController.text.trim();
    final senha = _senhaController.text;

    switch (_modo) {
      case _ModoAutenticacaoRemota.entrar:
        await _executar(() => remoto.entrar(email: email, senha: senha));
        return;
      case _ModoAutenticacaoRemota.cadastrar:
        await _executar(() async {
          final precisaConfirmar = await remoto.cadastrar(
            email: email,
            senha: senha,
          );
          if (!mounted) return;
          setState(() => _modo = _ModoAutenticacaoRemota.entrar);
          _definirMensagem(
            precisaConfirmar
                ? 'Conta criada. Enviamos um link de confirmação para seu e-mail. Confirme o endereço antes de entrar.'
                : 'Conta criada e autenticada. A confirmação por e-mail não está exigida neste projeto.',
          );
        });
        return;
      case _ModoAutenticacaoRemota.recuperar:
        await _executar(() async {
          await remoto.solicitarRecuperacao(email);
          _definirMensagem(
            'Se houver uma conta para esse e-mail, enviaremos as instruções de recuperação.',
          );
        });
        return;
      case _ModoAutenticacaoRemota.novaSenha:
        await _executar(() async {
          await remoto.definirNovaSenha(senha);
          if (!mounted) return;
          setState(() => _modo = _ModoAutenticacaoRemota.entrar);
          _senhaController.clear();
          _confirmarSenhaController.clear();
          _definirMensagem(
            'Senha atualizada. Entre novamente com a nova senha.',
          );
        });
        return;
    }
  }

  Future<void> _reenviar() async {
    final remoto = ref.read(autenticacaoRemotaProvider);
    if (remoto == null) return;
    final erro = _validarEmail(_emailController.text);
    if (erro != null) {
      _definirMensagem(erro, erro: true);
      return;
    }
    await _executar(() async {
      await remoto.reenviarConfirmacao(_emailController.text.trim());
      _definirMensagem(
        'Se a conta existir e ainda não estiver confirmada, enviaremos outro link. Aguarde alguns minutos antes de solicitar novamente.',
      );
    });
  }

  Future<void> _sair() async {
    final remoto = ref.read(autenticacaoRemotaProvider);
    if (remoto == null) return;
    await _executar(() async {
      await remoto.sair();
      if (mounted) setState(() => _modo = _ModoAutenticacaoRemota.entrar);
    });
  }

  void _voltarAoModoIndividual() {
    final usuarioLocal = ref.read(sessionProvider).value;
    context.go(usuarioLocal == null ? '/login' : '/home');
  }

  @override
  Widget build(BuildContext context) {
    final remoto = ref.watch(autenticacaoRemotaProvider);
    final estadoAsync = ref.watch(estadoSessaoRemotaProvider);
    final estado = estadoAsync.value ?? remoto?.estadoAtual;
    final autenticado = estado?.autenticado == true;

    ref.listen(estadoSessaoRemotaProvider, (anterior, proximo) {
      final evento = proximo.value?.evento;
      if (evento == EventoSessaoRemota.recuperacaoSenha) {
        setState(() {
          _modo = _ModoAutenticacaoRemota.novaSenha;
          _mensagem = 'Defina uma nova senha para sua conta compartilhada.';
          _mensagemErro = false;
        });
      } else if (evento == EventoSessaoRemota.entrou &&
          proximo.value?.emailConfirmado == true &&
          anterior?.value?.emailConfirmado != true) {
        _definirMensagem('E-mail confirmado. Sua conta está conectada.');
      } else if (evento == EventoSessaoRemota.saiu && _tinhaSessao) {
        _definirMensagem('A sessão remota foi encerrada.');
      } else if (evento == EventoSessaoRemota.falhaConexao) {
        _definirMensagem(
          'Sem conexão com o serviço. Não acesse dados compartilhados até que o servidor valide sua sessão.',
          erro: true,
        );
      }
      _tinhaSessao = proximo.value?.autenticado ?? false;
    });

    if (remoto == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Áreas compartilhadas')),
        body: _layout(
          context,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 16),
            Text(
              'A conexão com áreas compartilhadas não está configurada neste aplicativo.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'O modo individual offline continua disponível. A conexão será habilitada quando a URL e a chave publicável de um ambiente Supabase forem fornecidas na compilação.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _voltarAoModoIndividual,
              child: const Text('Voltar ao modo individual'),
            ),
          ],
        ),
      );
    }

    if (autenticado && _modo != _ModoAutenticacaoRemota.novaSenha) {
      return Scaffold(
        appBar: AppBar(title: const Text('Áreas compartilhadas')),
        body: _layout(
          context,
          children: [
            const CircleAvatar(
              radius: 32,
              child: Icon(Icons.cloud_done_outlined, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              estado?.email ?? '',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              estado?.emailConfirmado == true
                  ? 'E-mail confirmado'
                  : 'Conta conectada; confirme o e-mail para concluir a ativação.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Esta etapa não libera dados de uma UAN. O acesso compartilhado será validado pelo servidor em uma etapa futura.',
              textAlign: TextAlign.center,
            ),
            if (_mensagem != null) ...[
              const SizedBox(height: 16),
              _aviso(context),
            ],
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: _carregando ? null : _sair,
              child: _carregando
                  ? const CircularProgressIndicator()
                  : const Text('Sair da conta compartilhada'),
            ),
            TextButton(
              onPressed: _voltarAoModoIndividual,
              child: const Text('Voltar ao modo individual'),
            ),
          ],
        ),
      );
    }

    final titulo = switch (_modo) {
      _ModoAutenticacaoRemota.entrar => 'Entrar em uma conta compartilhada',
      _ModoAutenticacaoRemota.cadastrar => 'Criar conta compartilhada',
      _ModoAutenticacaoRemota.recuperar => 'Recuperar senha',
      _ModoAutenticacaoRemota.novaSenha => 'Definir nova senha',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Áreas compartilhadas')),
      body: _layout(
        context,
        children: [
          const Icon(Icons.groups_outlined, size: 48),
          const SizedBox(height: 12),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_modo != _ModoAutenticacaoRemota.novaSenha) ...[
                  TextFormField(
                    key: const Key('email-remoto'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'E-mail'),
                    validator: _validarEmail,
                  ),
                  const SizedBox(height: 12),
                ],
                if (_modo != _ModoAutenticacaoRemota.recuperar) ...[
                  TextFormField(
                    key: const Key('senha-remota'),
                    controller: _senhaController,
                    obscureText: !_mostrarSenha,
                    autofillHints: _modo == _ModoAutenticacaoRemota.entrar
                        ? const [AutofillHints.password]
                        : const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: _modo == _ModoAutenticacaoRemota.novaSenha
                          ? 'Nova senha'
                          : 'Senha (mínimo de 8 caracteres)',
                      suffixIcon: IconButton(
                        tooltip: _mostrarSenha
                            ? 'Ocultar senha'
                            : 'Mostrar senha',
                        onPressed: () =>
                            setState(() => _mostrarSenha = !_mostrarSenha),
                        icon: Icon(
                          _mostrarSenha
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: _modo == _ModoAutenticacaoRemota.entrar
                        ? (valor) => valor == null || valor.isEmpty
                              ? 'Informe a senha.'
                              : null
                        : _validarSenha,
                  ),
                  if (_modo != _ModoAutenticacaoRemota.entrar) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('confirmar-senha-remota'),
                      controller: _confirmarSenhaController,
                      obscureText: !_mostrarConfirmacao,
                      decoration: InputDecoration(
                        labelText: 'Confirmar senha',
                        suffixIcon: IconButton(
                          tooltip: _mostrarConfirmacao
                              ? 'Ocultar senha'
                              : 'Mostrar senha',
                          onPressed: () => setState(
                            () => _mostrarConfirmacao = !_mostrarConfirmacao,
                          ),
                          icon: Icon(
                            _mostrarConfirmacao
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                      validator: _validarConfirmacao,
                    ),
                  ],
                ],
                if (_mensagem != null) ...[
                  const SizedBox(height: 16),
                  _aviso(context),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _carregando ? null : _enviar,
                  child: _carregando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_rotuloBotao),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (_modo == _ModoAutenticacaoRemota.entrar) ...[
            TextButton(
              onPressed: _carregando
                  ? null
                  : () => setState(() {
                      _modo = _ModoAutenticacaoRemota.cadastrar;
                      _mensagem = null;
                    }),
              child: const Text('Criar conta'),
            ),
            TextButton(
              onPressed: _carregando
                  ? null
                  : () => setState(() {
                      _modo = _ModoAutenticacaoRemota.recuperar;
                      _mensagem = null;
                    }),
              child: const Text('Esqueci minha senha'),
            ),
            TextButton(
              onPressed: _carregando ? null : _reenviar,
              child: const Text('Reenviar confirmação de e-mail'),
            ),
          ] else
            TextButton(
              onPressed: _carregando
                  ? null
                  : () => setState(() {
                      _modo = _ModoAutenticacaoRemota.entrar;
                      _mensagem = null;
                    }),
              child: const Text('Voltar para entrar'),
            ),
          TextButton(
            onPressed: _voltarAoModoIndividual,
            child: const Text('Voltar ao modo individual'),
          ),
        ],
      ),
    );
  }

  String get _rotuloBotao => switch (_modo) {
    _ModoAutenticacaoRemota.entrar => 'Entrar',
    _ModoAutenticacaoRemota.cadastrar => 'Criar conta',
    _ModoAutenticacaoRemota.recuperar => 'Enviar instruções',
    _ModoAutenticacaoRemota.novaSenha => 'Salvar nova senha',
  };

  Widget _layout(BuildContext context, {required List<Widget> children}) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _aviso(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _mensagemErro
              ? esquema.errorContainer
              : esquema.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _mensagem!,
          style: TextStyle(
            color: _mensagemErro
                ? esquema.onErrorContainer
                : esquema.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}
