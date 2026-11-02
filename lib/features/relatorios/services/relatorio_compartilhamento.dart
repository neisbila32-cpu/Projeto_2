import 'dart:io';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

typedef CompartilharArquivo = Future<ShareResult> Function(ShareParams params);

class RelatorioCompartilhamento {
  RelatorioCompartilhamento({CompartilharArquivo? compartilhar})
    : _compartilhar = compartilhar ?? SharePlus.instance.share;

  final CompartilharArquivo _compartilhar;

  Future<ShareResult> compartilharPdf({
    required Uint8List conteudo,
    required String nome,
  }) async {
    final arquivo = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}$nome',
    );
    await arquivo.writeAsBytes(conteudo, flush: true);
    return _compartilhar(
      ShareParams(
        files: [XFile(arquivo.path, mimeType: 'application/pdf')],
        text: nome,
      ),
    );
  }
}
