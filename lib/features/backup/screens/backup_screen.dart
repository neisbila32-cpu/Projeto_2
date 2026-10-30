import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:projeto_2/core/utils/app_exception.dart';
import 'package:projeto_2/features/auth/providers/auth_providers.dart';
import 'package:projeto_2/features/backup/providers/backup_providers.dart';
import 'package:projeto_2/features/historico/providers/historico_providers.dart';
import 'package:projeto_2/features/produtos/providers/produto_providers.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _exportando = false;
  bool _restaurando = false;
  String? _ultimoBackupIso;

  @override
  void initState() {
    super.initState();
    _carregarUltimoBackup();
  }

  Future<void> _carregarUltimoBackup() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _ultimoBackupIso = prefs.getString('ultimo_backup');
    });
  }

  static String? _formatarDataIso(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      final partes = iso.split('T');
      if (partes.length < 2) return null;
      final dataPartes = partes[0].split('-');
      final horaPartes = partes[1].split(':');
      if (dataPartes.length < 3 || horaPartes.length < 2) return null;
      return '${dataPartes[2]}/${dataPartes[1]}/${dataPartes[0]} '
          '${horaPartes[0]}:${horaPartes[1]}';
    } catch (_) {
      return null;
    }
  }

  Future<void> _exportarECopartilhar() async {
    setState(() => _exportando = true);
    try {
      final arquivo = await ref.read(backupServiceProvider).exportar();
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(arquivo.path)],
          text: 'Backup do Estoque UAN',
        ),
      );
      if (result.status == ShareResultStatus.success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('ultimo_backup', DateTime.now().toIso8601String());
        if (!mounted) return;
        _carregarUltimoBackup();
      }
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível exportar o backup.')),
      );
    } finally {
      if (mounted) {
        setState(() => _exportando = false);
      }
    }
  }

  Future<void> _restaurar() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return;
    final path = files.first.path;
    if (path == null) return;

    final buildContext = context;
    final confirmado = await showDialog<bool>(
      context: buildContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restaurar este backup?'),
        content: Text(
          'Arquivo: ${files.first.name}\n\n'
          'Todos os dados atuais serão substituídos. '
          'Esta ação não pode ser desfeita pelo app.',
        ),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => dialogContext.pop(true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirmado != true) return;

    setState(() => _restaurando = true);
    try {
      await ref.read(backupServiceProvider).restaurar(File(path));

      ref.invalidate(produtosProvider);
      ref.invalidate(categoriasAtivasProvider);
      ref.invalidate(categoriasTodasProvider);
      ref.invalidate(unidadesAtivasProvider);
      ref.invalidate(unidadesTodasProvider);
      ref.invalidate(historicoProvider);
      ref.invalidate(existeUsuarioProvider);

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Backup restaurado'),
          content: const Text('Entre novamente com um usuário do backup.'),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      ref.read(sessionProvider.notifier).sair();
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível restaurar o backup.')),
      );
    } finally {
      if (mounted) {
        setState(() => _restaurando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuarioAsync = ref.watch(sessionProvider);

    if (usuarioAsync.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final usuario = usuarioAsync.value;
    if (usuario == null || !usuario.isAdmin) {
      return const Scaffold(
        body: Center(
          child: Text('Acesso restrito ao administrador.'),
        ),
      );
    }

    final ultimoBackupTexto = _ultimoBackupIso == null
        ? 'Nenhum backup feito ainda'
        : 'Último backup: ${_formatarDataIso(_ultimoBackupIso)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup e restauração'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Os dados deste app ficam apenas neste aparelho. '
              'Faça backup com frequência e guarde o arquivo '
              'fora do aparelho (WhatsApp, e-mail ou Google Drive).',
            ),
            const SizedBox(height: 24),
            Text(
              ultimoBackupTexto,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Exportar backup',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _exportando ? null : _exportarECopartilhar,
                        icon: _exportando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.file_download),
                        label: Text(
                          _exportando
                              ? 'Exportando...'
                              : 'Exportar e compartilhar',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Restaurar backup',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'A restauração substitui TODOS os dados atuais '
                      'pelos do arquivo escolhido. Uma cópia de segurança '
                      'do estado atual será guardada no aparelho.',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _restaurando ? null : _restaurar,
                        icon: _restaurando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.restore),
                        label: Text(
                          _restaurando
                              ? 'Restaurando...'
                              : 'Escolher arquivo e restaurar',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}