import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

import 'package:projeto_2/features/painel/models/painel_dados.dart';
import 'package:projeto_2/features/painel/services/painel_pdf.dart';
import 'package:projeto_2/features/relatorios/services/relatorio_compartilhamento.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'PDF do Painel mostra o ranking e os dados do período selecionado',
    () async {
      final intervalo = Intervalo(DateTime(2026, 11, 1), DateTime(2026, 11, 7));
      final dados = PainelDados(
        intervalo: intervalo,
        resumo: const ResumoMovimentos(
          entradas: 2,
          saidas: 9,
          perdas: 1,
          ajustes: 0,
        ),
        porCategoria: const [
          ItemRanking(nome: 'Hortifruti', saidas: 6, categoria: 'Hortifruti'),
          ItemRanking(nome: 'Mercearia', saidas: 3, categoria: 'Mercearia'),
        ],
        porProduto: const [],
        porDia: [
          DiaMovimento(DateTime(2026, 11, 1), 2),
          DiaMovimento(DateTime(2026, 11, 2), 4),
          DiaMovimento(DateTime(2026, 11, 3), 1),
          DiaMovimento(DateTime(2026, 11, 4), 0),
          DiaMovimento(DateTime(2026, 11, 5), 2),
          DiaMovimento(DateTime(2026, 11, 6), 1),
          DiaMovimento(DateTime(2026, 11, 7), 1),
        ],
      );

      final bytes = await PainelPdf.gerar(
        dados,
        atalho: PainelAtalho.seteDias,
        rankingProdutos: false,
        geradoEm: DateTime(2026, 11, 8, 10, 30),
      );
      final conteudo = latin1.decode(bytes);
      final texto = _extrairTextoPdf(bytes);

      expect(conteudo, startsWith('%PDF-'));
      expect(conteudo, contains('%%EOF'));
      expect(conteudo, contains('/Type/Page'));
      expect(conteudo, isNot(contains('/Subtype/Image')));
      expect(
        RegExp(
          r'0 0 [\d.]+ 13 re [\d.]+ [\d.]+ [\d.]+ rg f',
        ).hasMatch(conteudo),
        isTrue,
      );
      expect(texto, contains('Paineldeestoque'));
      expect(texto, contains('7dias'));
      expect(texto, contains('01/11/2026a07/11/2026'));
      expect(texto, contains('08/11/202610:30'));
      expect(texto, contains('Hortifruti'));
      expect(texto, contains('Mercearia'));
      expect(texto, contains('02/11/20264'));
      expect(texto, contains('7/11'));
    },
  );

  test(
    'PDF de mês longo preserva os 31 dias e inclui gráfico vetorial',
    () async {
      final dias = [
        for (var dia = 1; dia <= 31; dia++)
          DiaMovimento(DateTime(2026, 1, dia), dia % 8),
      ];
      final bytes = await PainelPdf.gerar(
        PainelDados(
          intervalo: Intervalo(DateTime(2026, 1, 1), DateTime(2026, 1, 31)),
          resumo: const ResumoMovimentos(
            entradas: 4,
            saidas: 31,
            perdas: 0,
            ajustes: 1,
          ),
          porCategoria: const [],
          porProduto: const [],
          porDia: dias,
        ),
        atalho: PainelAtalho.esteMes,
        rankingProdutos: false,
        geradoEm: DateTime(2026, 2, 1),
      );
      final conteudo = latin1.decode(bytes);
      final texto = _extrairTextoPdf(bytes);

      expect(
        RegExp(r'/Type\s*/Page\b').allMatches(conteudo).length,
        greaterThan(1),
      );
      expect(texto, contains('Estemês'));
      expect(texto, contains('01/01/2026a31/01/2026'));
      expect(texto, contains('31/01/2026'));
      expect(texto, contains('31'));
      expect(
        RegExp(
          r'\bre\s+[0-9.]+\s+[0-9.]+\s+[0-9.]+\s+rg\s+f\b',
        ).hasMatch(conteudo),
        isTrue,
      );
    },
  );

  test('modo Produtos exporta o ranking de produtos e sua unidade', () async {
    final base = _dadosMinimos();
    final dados = PainelDados(
      intervalo: base.intervalo,
      resumo: base.resumo,
      porCategoria: const [],
      porProduto: const [
        ItemRanking(
          nome: 'Arroz integral',
          saidas: 4,
          categoria: 'Mercearia',
          quantidade: 1500,
          unidadeSigla: 'kg',
          fracionavel: true,
        ),
      ],
      porDia: base.porDia,
    );
    final bytes = await PainelPdf.gerar(
      dados,
      atalho: PainelAtalho.trintaDias,
      rankingProdutos: true,
      geradoEm: DateTime(2026, 11, 2),
    );
    final texto = _extrairTextoPdf(bytes);

    expect(texto, contains('30dias'));
    expect(texto, contains('Arrozintegral'));
    expect(texto, contains('1,5kg'));
    expect(texto, contains('Legendadecoresporcategoria:'));
    expect(texto, contains('Mercearia'));
  });

  test('PDF gerado pelo Painel pode ser enviado ao compartilhamento', () async {
    final bytes = await PainelPdf.gerar(
      _dadosMinimos(),
      atalho: PainelAtalho.seteDias,
      rankingProdutos: false,
      geradoEm: DateTime(2026, 11, 2),
    );
    XFile? compartilhado;
    final servico = RelatorioCompartilhamento(
      compartilhar: (params) async {
        compartilhado = params.files!.single;
        return ShareResult('whatsapp', ShareResultStatus.success);
      },
    );

    final resultado = await servico.compartilharPdf(
      conteudo: bytes,
      nome: 'painel_7_dias_20261102_0000.pdf',
    );

    expect(resultado.status, ShareResultStatus.success);
    expect(compartilhado?.mimeType, 'application/pdf');
    expect(compartilhado?.name, 'painel_7_dias_20261102_0000.pdf');
    expect(
      latin1.decode(await compartilhado!.readAsBytes()),
      startsWith('%PDF-'),
    );
    await File(compartilhado!.path).delete();
  });
}

PainelDados _dadosMinimos() => PainelDados(
  intervalo: Intervalo(DateTime(2026, 11, 1), DateTime(2026, 11, 7)),
  resumo: const ResumoMovimentos(entradas: 1, saidas: 1, perdas: 0, ajustes: 0),
  porCategoria: const [
    ItemRanking(nome: 'Mercearia', saidas: 1, categoria: 'Mercearia'),
  ],
  porProduto: const [],
  porDia: [DiaMovimento(DateTime(2026, 11, 2), 1)],
);

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
    for (final recurso in RegExp(
      r'/(F\d+)\s+(\d+)\s+0\s+R',
    ).allMatches(pagina)) {
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
