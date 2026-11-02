import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:projeto_2/core/theme/categoria_cores.dart';
import 'package:projeto_2/core/utils/quantidade_utils.dart';
import 'package:projeto_2/features/painel/models/painel_dados.dart';

class PainelPdf {
  PainelPdf._();

  static final Future<pw.ThemeData> _tema = _carregarTema();

  static Future<pw.ThemeData> _carregarTema() async => pw.ThemeData.withFont(
    base: pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf')),
    bold: pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf')),
  );

  static Future<Uint8List> gerar(
    PainelDados dados, {
    required PainelAtalho atalho,
    required bool rankingProdutos,
    DateTime? geradoEm,
  }) async {
    final geracao = geradoEm ?? DateTime.now();
    final documento = pw.Document(
      compress: false,
      theme: await _tema,
      title: 'Painel de estoque - ${atalho.rotulo}',
      subject: 'Gráficos do Painel do Estoque UAN',
      creator: 'Estoque UAN',
    );
    final intervalo =
        '${_data(dados.intervalo.inicio)} a ${_data(dados.intervalo.fim)}';
    final tituloRanking = rankingProdutos
        ? 'Produtos com mais saída'
        : 'Gêneros com mais saída';
    final itens = rankingProdutos ? dados.porProduto : dados.porCategoria;

    documento.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => _cabecalho(
          titulo: 'Painel de estoque',
          atalho: atalho,
          intervalo: intervalo,
          geradoEm: geracao,
        ),
        footer: _rodape,
        build: (_) => [
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              _indicador('Movimentações', dados.resumo.total),
              pw.SizedBox(width: 12),
              _indicador('Saídas', dados.resumo.saidas),
              pw.SizedBox(width: 12),
              _indicador('Perdas', dados.resumo.perdas),
            ],
          ),
          pw.SizedBox(height: 22),
          pw.Text(
            tituloRanking,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Eixo horizontal: número de saídas registradas'),
          pw.SizedBox(height: 12),
          if (itens.isEmpty)
            pw.Text('Sem saídas no período selecionado.')
          else
            ...itens.map((item) => _linhaRanking(item, dados, rankingProdutos)),
          if (rankingProdutos && itens.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text('Legenda de cores por categoria:'),
            pw.SizedBox(height: 5),
            pw.Wrap(
              spacing: 14,
              runSpacing: 5,
              children: itens
                  .where((item) => item.categoria != null)
                  .map((item) => item.categoria!)
                  .toSet()
                  .map(_legendaCategoria)
                  .toList(),
            ),
          ],
          pw.SizedBox(height: 8),
          pw.Text(
            'Nas barras, cada registro corresponde a uma saída. Quantidades de unidades diferentes não são somadas.',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    );

    documento.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => _cabecalho(
          titulo: 'Dias com mais movimentação',
          atalho: atalho,
          intervalo: intervalo,
          geradoEm: geracao,
        ),
        footer: _rodape,
        build: (_) => [
          pw.SizedBox(height: 14),
          pw.Text('Eixo horizontal: data'),
          pw.Text('Eixo vertical: movimentações registradas por dia'),
          pw.SizedBox(height: 8),
          _graficoDias(dados.porDia),
          pw.SizedBox(height: 8),
          pw.Text('Valores correspondentes ao gráfico'),
          pw.SizedBox(height: 5),
          pw.TableHelper.fromTextArray(
            headers: const ['Data', 'Movimentações'],
            data: [
              for (final dia in dados.porDia) [_data(dia.dia), '${dia.total}'],
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 8,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey800,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 3,
            ),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              1: const pw.FlexColumnWidth(1),
            },
          ),
        ],
      ),
    );
    return documento.save();
  }

  static pw.Widget _cabecalho({
    required String titulo,
    required PainelAtalho atalho,
    required String intervalo,
    required DateTime geradoEm,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'Estoque UAN · Painel',
        style: pw.TextStyle(
          fontSize: 9,
          color: PdfColors.blueGrey700,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.SizedBox(height: 3),
      pw.Text(
        titulo,
        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 3),
      pw.Text('Período selecionado: ${atalho.rotulo} ($intervalo)'),
      pw.Text('Gerado em ${_dataHora(geradoEm)}'),
      pw.Divider(color: PdfColors.blueGrey300),
    ],
  );

  static pw.Widget _indicador(String titulo, int valor) => pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '$valor',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(titulo, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    ),
  );

  static pw.Widget _linhaRanking(
    ItemRanking item,
    PainelDados dados,
    bool rankingProdutos,
  ) {
    final maximo = (rankingProdutos ? dados.porProduto : dados.porCategoria)
        .fold<int>(
          0,
          (maximo, atual) => maximo > atual.saidas ? maximo : atual.saidas,
        );
    final cor = _corCategoria(item.categoria ?? item.nome);
    final escala = maximo == 0 ? 0 : (item.saidas / maximo * 1000).round();
    final quantidade = rankingProdutos
        ? ' · ${QuantidadeUtils.format(item.quantidade ?? 0, fracionavel: item.fracionavel)} ${item.unidadeSigla ?? ''}'
        : '';
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 190,
            child: pw.Text(
              '${item.nome}$quantidade',
              maxLines: 2,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.ClipRRect(
              horizontalRadius: 5,
              verticalRadius: 5,
              child: pw.Container(
                height: 13,
                color: PdfColors.grey200,
                child: pw.Row(
                  children: [
                    if (escala > 0)
                      pw.Expanded(
                        flex: escala,
                        child: pw.Container(color: cor, height: 13),
                      ),
                    if (escala < 1000)
                      pw.Expanded(
                        flex: 1000 - escala,
                        child: pw.SizedBox(height: 13),
                      ),
                  ],
                ),
              ),
            ),
          ),
          pw.SizedBox(width: 12),
          pw.SizedBox(
            width: 28,
            child: pw.Text(
              '${item.saidas}',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _graficoDias(List<DiaMovimento> dias) {
    final maximo = dias.fold<int>(
      0,
      (maximo, dia) => maximo > dia.total ? maximo : dia.total,
    );
    return pw.Container(
      height: 150,
      padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blueGrey400)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < dias.length; i++)
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 1),
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text(
                      '${dias[i].total}',
                      style: const pw.TextStyle(fontSize: 6),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Expanded(
                      child: pw.Align(
                        alignment: pw.Alignment.bottomCenter,
                        child: pw.Container(
                          width: double.infinity,
                          height: maximo == 0
                              ? 2
                              : (dias[i].total / maximo * 85)
                                    .clamp(2.0, 85.0)
                                    .toDouble(),
                          decoration: pw.BoxDecoration(
                            color: dias[i].total == maximo && maximo > 0
                                ? PdfColors.blue
                                : PdfColors.lightBlue300,
                            borderRadius: pw.BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      '${dias[i].dia.day}/${dias[i].dia.month}',
                      style: const pw.TextStyle(fontSize: 5),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _legendaCategoria(String categoria) => pw.Row(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.Container(width: 8, height: 8, color: _corCategoria(categoria)),
      pw.SizedBox(width: 4),
      pw.Text(categoria, style: const pw.TextStyle(fontSize: 8)),
    ],
  );

  static PdfColor _corCategoria(String categoria) {
    final Color cor = CategoriaCores.de(categoria, Brightness.light);
    return PdfColor.fromInt(cor.toARGB32());
  }

  static pw.Widget _rodape(pw.Context context) => pw.Container(
    alignment: pw.Alignment.centerRight,
    margin: const pw.EdgeInsets.only(top: 8),
    child: pw.Text(
      'Página ${context.pageNumber} de ${context.pagesCount}',
      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
    ),
  );

  static String _data(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/'
      '${data.month.toString().padLeft(2, '0')}/${data.year}';

  static String _dataHora(DateTime data) =>
      '${_data(data)} ${data.hour.toString().padLeft(2, '0')}:'
      '${data.minute.toString().padLeft(2, '0')}';
}
