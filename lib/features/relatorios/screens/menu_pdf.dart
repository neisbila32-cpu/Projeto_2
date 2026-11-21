import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../services/relatorio_compartilhamento.dart';

typedef DocumentoPdf = ({String nome, Uint8List bytes});

class MenuPdf extends StatefulWidget {
  const MenuPdf({super.key, required this.gerar});
  final Future<DocumentoPdf> Function()? gerar;
  @override
  State<MenuPdf> createState() => _MenuPdfState();
}

class _MenuPdfState extends State<MenuPdf> {
  bool ocupado = false;

  Future<void> executar(bool salvar) async {
    final gerar = widget.gerar;
    if (ocupado || gerar == null) return;
    setState(() => ocupado = true);
    String mensagem;
    try {
      final doc = await gerar();
      if (!mounted) return;
      if (salvar) {
        final destino = await FilePicker.saveFile(
          fileName: doc.nome,
          bytes: doc.bytes,
          mimeType: 'application/pdf',
        );
        mensagem = destino == null ? 'Salvamento cancelado.' : 'PDF salvo.';
      } else {
        final resultado = await RelatorioCompartilhamento().compartilharPdf(
          conteudo: doc.bytes,
          nome: doc.nome,
        );
        mensagem = switch (resultado.status) {
          ShareResultStatus.success => 'PDF compartilhado.',
          ShareResultStatus.dismissed => 'Compartilhamento cancelado.',
          ShareResultStatus.unavailable => 'Compartilhamento indisponível.',
        };
      }
    } catch (_) {
      mensagem = 'Não foi possível exportar o PDF.';
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensagem)));
    }
  }

  @override
  Widget build(BuildContext context) => PopupMenuButton<bool>(
    enabled: !ocupado && widget.gerar != null,
    tooltip: 'Opções de PDF',
    icon: const Icon(Icons.more_vert),
    onSelected: executar,
    itemBuilder: (_) => const [
      PopupMenuItem(
        value: false,
        child: ListTile(
          leading: Icon(Icons.share),
          title: Text('Gerar e compartilhar PDF'),
        ),
      ),
      PopupMenuItem(
        value: true,
        child: ListTile(
          leading: Icon(Icons.save_alt),
          title: Text('Salvar PDF no dispositivo'),
        ),
      ),
    ],
  );
}
