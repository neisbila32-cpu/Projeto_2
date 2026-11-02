import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

import 'package:projeto_2/features/relatorios/models/relatorio_dados.dart';
import 'package:projeto_2/features/relatorios/services/relatorio_compartilhamento.dart';
import 'package:projeto_2/features/relatorios/services/relatorio_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'PDF de estoque contém estrutura válida e os dados do relatório',
    () async {
      final bytes = await RelatorioPdf.estoque(const [
        LinhaEstoqueRelatorio(
          produtoId: 7,
          produtoNome: 'Arroz integral',
          categoriaNome: 'Mercearia',
          unidadeSigla: 'kg',
          fracionavel: true,
          saldo: 1500,
          ativo: true,
        ),
      ], geradoEm: DateTime(2026, 11, 2, 9, 30));
      final conteudo = latin1.decode(bytes);
      final texto = _extrairTextoPdf(bytes);

      expect(conteudo, startsWith('%PDF-'));
      expect(conteudo, contains('%%EOF'));
      expect(conteudo, contains('/Title'));
      expect(texto, contains('Arrozintegral'));
      expect(texto, contains('1,5kg'));
    },
  );

  test(
    'PDF de movimentações pagina relatórios extensos e inclui o período',
    () async {
      final linhas = [
        for (var i = 0; i < 140; i++)
          LinhaMovimentacaoRelatorio(
            id: i + 1,
            dataHora: DateTime(2026, 11, 1, 10).add(Duration(minutes: i)),
            produtoNome: 'Produto ${i + 1}',
            unidadeSigla: 'kg',
            fracionavel: true,
            tipo: 'Entrada',
            delta: 500,
            saldoApos: 1000 + i * 500,
            usuarioNome: 'Operador',
            observacao: 'Reposição de teste',
          ),
      ];

      final bytes = await RelatorioPdf.movimentacoes(
        linhas,
        inicio: DateTime(2026, 11, 1),
        fim: DateTime(2026, 11, 30),
        geradoEm: DateTime(2026, 12, 1, 8, 15),
      );
      final conteudo = latin1.decode(bytes);
      final texto = _extrairTextoPdf(bytes);
      final paginas = RegExp(r'/Type\s*/Page\b').allMatches(conteudo).length;

      expect(conteudo, startsWith('%PDF-'));
      expect(texto, contains('Produto140'));
      expect(texto, contains('01/11/2026'));
      expect(paginas, greaterThan(1));
    },
  );

  test('compartilhador entrega arquivo PDF real para share_plus', () async {
    final bytes = await RelatorioPdf.estoque(const []);
    XFile? arquivoCompartilhado;
    var textoCompartilhado = '';
    final compartilhador = RelatorioCompartilhamento(
      compartilhar: (params) async {
        arquivoCompartilhado = params.files!.single;
        textoCompartilhado = params.text ?? '';
        return ShareResult('email', ShareResultStatus.success);
      },
    );

    final resultado = await compartilhador.compartilharPdf(
      conteudo: bytes,
      nome: 'relatorio_teste.pdf',
    );

    expect(resultado.status, ShareResultStatus.success);
    expect(arquivoCompartilhado?.mimeType, 'application/pdf');
    expect(textoCompartilhado, 'relatorio_teste.pdf');
    expect(
      latin1.decode(await arquivoCompartilhado!.readAsBytes()),
      startsWith('%PDF-'),
    );
    await File(arquivoCompartilhado!.path).delete();
  });
}

String _extrairTextoPdf(Uint8List bytes) {
  final pdf = latin1.decode(bytes);
  final objetos = <String, String>{};
  for (final objeto in RegExp(
    r'(\d+)\s+0\s+obj(.*?)endobj',
    dotAll: true,
  ).allMatches(pdf)) {
    objetos[objeto.group(1)!] = objeto.group(2)!;
  }

  final texto = StringBuffer();
  for (final pagina in objetos.values.where((o) => o.contains('/Type/Page/'))) {
    final fontes = <String, Map<String, String>>{};
    final recursos = RegExp(r'/(F\d+)\s+(\d+)\s+0\s+R').allMatches(pagina);
    for (final recurso in recursos) {
      final fonte = objetos[recurso.group(2)!];
      if (fonte == null) continue;
      final cmapId = RegExp(
        r'/ToUnicode\s+(\d+)\s+0\s+R',
      ).firstMatch(fonte)?.group(1);
      final cmap = cmapId == null ? null : objetos[cmapId];
      if (cmap == null) continue;
      final mapa = <String, String>{};
      for (final bloco in RegExp(
        r'\d+\s+beginbfchar(.*?)endbfchar',
        dotAll: true,
      ).allMatches(cmap)) {
        for (final par in RegExp(
          r'<([0-9A-Fa-f]{4})>\s*<([0-9A-Fa-f]{4,8})>',
        ).allMatches(bloco.group(1)!)) {
          mapa[par.group(1)!.toUpperCase()] = String.fromCharCode(
            int.parse(par.group(2)!, radix: 16),
          );
        }
      }
      fontes[recurso.group(1)!] = mapa;
    }

    final conteudoId = RegExp(
      r'/Contents\s+(\d+)\s+0\s+R',
    ).firstMatch(pagina)?.group(1);
    final stream = conteudoId == null ? null : objetos[conteudoId];
    if (stream == null) continue;
    for (final bloco in RegExp(r'BT(.*?)ET', dotAll: true).allMatches(stream)) {
      final textoPdf = bloco.group(1)!;
      final fonte = RegExp(
        r'/(F\d+)\s+[\d.]+\s+Tf',
      ).firstMatch(textoPdf)?.group(1);
      final mapa = fonte == null ? null : fontes[fonte];
      if (mapa == null) continue;
      for (final grupo in RegExp(r'<([0-9A-Fa-f]+)>').allMatches(textoPdf)) {
        final codigos = grupo.group(1)!.toUpperCase();
        for (var i = 0; i + 4 <= codigos.length; i += 4) {
          texto.write(mapa[codigos.substring(i, i + 4)] ?? '');
        }
      }
    }
  }
  return texto.toString();
}
