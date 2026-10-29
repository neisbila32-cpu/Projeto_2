import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:projeto_2/core/utils/app_exception.dart';
import 'package:projeto_2/features/auth/providers/auth_providers.dart';
import 'package:projeto_2/features/produtos/models/categoria.dart';
import 'package:projeto_2/features/produtos/models/produto.dart';
import 'package:projeto_2/features/produtos/models/unidade.dart';
import 'package:projeto_2/features/produtos/providers/produto_providers.dart';

class ProdutoFormScreen extends ConsumerStatefulWidget {
  final int? produtoId;

  const ProdutoFormScreen({super.key, this.produtoId});

  @override
  ConsumerState<ProdutoFormScreen> createState() => _ProdutoFormScreenState();
}

class _ProdutoFormScreenState extends ConsumerState<ProdutoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  bool _carregando = false;
  bool _inicializado = false;
  int? _categoriaId;
  int? _unidadeId;

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoriaId == null || _unidadeId == null) return;

    setState(() => _carregando = true);

    try {
      final usuario = ref.read(sessionProvider).value;
      if (usuario == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usu\u00e1rio n\u00e3o encontrado.')),
        );
        return;
      }

      if (widget.produtoId == null) {
        await ref.read(produtoRepositoryProvider).criar(
          nome: _nomeController.text.trim(),
          categoriaId: _categoriaId!,
          unidadeId: _unidadeId!,
          usuarioId: usuario.id,
        );
      } else {
        await ref.read(produtoRepositoryProvider).atualizar(
          id: widget.produtoId!,
          nome: _nomeController.text.trim(),
          categoriaId: _categoriaId!,
          unidadeId: _unidadeId!,
        );
      }

      if (!mounted) return;
      ref.invalidate(produtosProvider);
      if (widget.produtoId != null) {
        ref.invalidate(produtoPorIdProvider(widget.produtoId!));
      }
      if (!mounted) return;
      context.pop();
    } on AppException catch (e) {
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

  Future<void> _definirAtivo(bool ativo) async {
    final produto = await ref.read(produtoPorIdProvider(widget.produtoId!).future);
    if (!mounted) return;
    if (produto == null) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(ativo ? 'Reativar produto' : 'Inativar produto'),
        content: Text(
          ativo
              ? 'Deseja reativar o produto "${produto.nome}"?'
              : 'Deseja inativar o produto "${produto.nome}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => context.pop(true),
            child: Text(ativo ? 'Reativar' : 'Inativar'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirmado != true) return;

    try {
      await ref.read(produtoRepositoryProvider).definirAtivo(
        widget.produtoId!,
        ativo,
      );
      if (!mounted) return;
      ref.invalidate(produtosProvider);
      ref.invalidate(produtoPorIdProvider(widget.produtoId!));
      if (!mounted) return;
      context.pop();
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro inesperado. Tente novamente.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final modoEdicao = widget.produtoId != null;

    AsyncValue<Produto?>? produtoAsync;
    AsyncValue<bool>? temMovAsync;
    if (modoEdicao) {
      produtoAsync = ref.watch(produtoPorIdProvider(widget.produtoId!));
      temMovAsync = ref.watch(produtoTemMovimentacoesProvider(widget.produtoId!));
    }
    final categoriasAsync = ref.watch(categoriasAtivasProvider);
    final unidadesAsync = ref.watch(unidadesAtivasProvider);

    if ((produtoAsync?.isLoading ?? false) ||
        categoriasAsync.isLoading ||
        unidadesAsync.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (categoriasAsync.hasError ||
        unidadesAsync.hasError ||
        (produtoAsync?.hasError ?? false)) {
      return const Scaffold(
        body: Center(child: Text('Erro ao carregar dados.')),
      );
    }

    final produto = produtoAsync?.value;
    final categorias = categoriasAsync.value ?? <Categoria>[];
    final unidades = unidadesAsync.value ?? <Unidade>[];
    final temMovimentacoes = temMovAsync?.value ?? false;

    if (modoEdicao && produto != null && !_inicializado) {
      _nomeController.text = produto.nome;
      _categoriaId = produto.categoriaId;
      _unidadeId = produto.unidadeId;
      _inicializado = true;
    }

    if (!modoEdicao && !_inicializado) {
      final filtro = ref.read(produtoFiltroProvider);
      final categoriaId = filtro.categoriaId;
      if (categoriaId != null && categorias.any((c) => c.id == categoriaId)) {
        _categoriaId = categoriaId;
      }
      _inicializado = true;
    }

    List<Categoria> categoriasLista = categorias;
    if (modoEdicao && produto != null) {
      if (!categorias.any((c) => c.id == produto.categoriaId)) {
        categoriasLista = [
          ...categorias,
          Categoria(
            id: produto.categoriaId,
            nome: produto.categoriaNome,
            ativa: false,
          ),
        ];
      }
    }

    List<Unidade> unidadesLista = unidades;
    if (modoEdicao && produto != null) {
      if (!unidades.any((u) => u.id == produto.unidadeId)) {
        unidadesLista = [
          ...unidades,
          Unidade(
            id: produto.unidadeId,
            sigla: produto.unidadeSigla,
            nome: produto.unidadeSigla,
            fracionavel: produto.unidadeFracionavel,
            ativa: false,
          ),
        ];
      }
    }

    final unidadeBloqueada = modoEdicao && temMovimentacoes;

    return Scaffold(
      appBar: AppBar(
        title: Text(modoEdicao ? 'Editar produto' : 'Novo produto'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (valor) {
                  if (valor == null || valor.trim().isEmpty) {
                    return 'Informe o nome do produto.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _categoriaId,
                items: categoriasLista.map((categoria) {
                  return DropdownMenuItem<int>(
                    value: categoria.id,
                    child: Text(
                      categoria.ativa
                          ? categoria.nome
                          : '${categoria.nome} (inativa)',
                    ),
                  );
                }).toList(),
                onChanged: (valor) {
                  setState(() => _categoriaId = valor);
                },
                decoration: const InputDecoration(labelText: 'Categoria'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _unidadeId,
                items: unidadesLista.map((unidade) {
                  return DropdownMenuItem<int>(
                    value: unidade.id,
                    child: Text(unidade.rotulo),
                  );
                }).toList(),
                onChanged: unidadeBloqueada
                    ? null
                    : (valor) {
                        setState(() => _unidadeId = valor);
                      },
                decoration: InputDecoration(
                  labelText: 'Unidade',
                  helperText: unidadeBloqueada
                      ? 'Unidade bloqueada: o produto j\u00e1 tem movimenta\u00e7\u00f5es.'
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              if (modoEdicao && produto != null) ...[
                Text(
                  'Saldo atual: ${produto.saldoFormatado}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _carregando ? null : _salvar,
                  child: _carregando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salvar'),
                ),
              ),
              if (modoEdicao && produto != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _carregando
                        ? null
                        : () => _definirAtivo(produto.ativo),
                    child: Text(
                      produto.ativo ? 'Inativar produto' : 'Reativar produto',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}