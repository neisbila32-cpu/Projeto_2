import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:projeto_2/core/utils/quantidade_utils.dart';
import 'package:projeto_2/features/relatorios/models/relatorio_dados.dart';

class RelatorioPdf {
  RelatorioPdf._();

  static final Future<pw.ThemeData> _tema = _carregarTema();

  static Future<pw.ThemeData> _carregarTema() async => pw.ThemeData.withFont(
    base: pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf')),
    bold: pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf')),
  );

  static Future<Uint8List> estoque(
    List<LinhaEstoqueRelatorio> linhas, {
    DateTime? geradoEm,
  }) async {
    final geracao = geradoEm ?? DateTime.now();
    const titulo = 'Posição atual do estoque';
    final documento = pw.Document(
      compress: false,
      theme: await _tema,
      title: titulo,
      subject: 'Estoque UAN',
      creator: 'Estoque UAN',
    );
    documento.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _cabecalho(
          titulo: titulo,
          geradoEm: geracao,
          detalhe:
              '${linhas.where((l) => l.ativo).length} produtos ativos · '
              '${linhas.length} produtos no total',
        ),
        footer: _rodape,
        build: (context) => [
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: const ['ID', 'Produto', 'Categoria', 'Saldo', 'Status'],
            data: [
              for (final linha in linhas)
                [
                  linha.produtoId.toString(),
                  linha.produtoNome,
                  linha.categoriaNome,
                  '${QuantidadeUtils.format(linha.saldo, fracionavel: linha.fracionavel)} ${linha.unidadeSigla}',
                  linha.ativo ? 'Ativo' : 'Inativo',
                ],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey800,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 5,
            ),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            columnWidths: {
              0: const pw.FlexColumnWidth(0.5),
              1: const pw.FlexColumnWidth(2.4),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(0.8),
            },
          ),
        ],
      ),
    );
    return documento.save();
  }

  static Future<Uint8List> movimentacoes(
    List<LinhaMovimentacaoRelatorio> linhas, {
    required DateTime inicio,
    required DateTime fim,
    DateTime? geradoEm,
  }) async {
    final geracao = geradoEm ?? DateTime.now();
    const titulo = 'Relatório de movimentações';
    final documento = pw.Document(
      compress: false,
      theme: await _tema,
      title: titulo,
      subject: 'Movimentações de estoque no período',
      creator: 'Estoque UAN',
    );
    documento.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _cabecalho(
          titulo: titulo,
          geradoEm: geracao,
          detalhe:
              'Período: ${_data(inicio)} a ${_data(fim)} · ${linhas.length} movimentações',
        ),
        footer: _rodape,
        build: (context) => [
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Data e hora',
              'Produto',
              'Tipo',
              'Variação',
              'Saldo após',
              'Responsável',
              'Observação',
            ],
            data: [
              for (final linha in linhas)
                [
                  _dataHora(linha.dataHora),
                  linha.produtoNome,
                  linha.tipo,
                  '${linha.delta > 0 ? '+' : ''}${QuantidadeUtils.format(linha.delta, fracionavel: linha.fracionavel)} ${linha.unidadeSigla}',
                  '${QuantidadeUtils.format(linha.saldoApos, fracionavel: linha.fracionavel)} ${linha.unidadeSigla}',
                  linha.usuarioNome,
                  linha.observacao ?? '',
                ],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey800,
            ),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 5,
            ),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.5),
              1: const pw.FlexColumnWidth(2.2),
              2: const pw.FlexColumnWidth(0.9),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1),
              5: const pw.FlexColumnWidth(1.5),
              6: const pw.FlexColumnWidth(2.2),
            },
          ),
        ],
      ),
    );
    return documento.save();
  }

  static pw.Widget _cabecalho({
    required String titulo,
    required DateTime geradoEm,
    required String detalhe,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'Estoque UAN',
        style: pw.TextStyle(
          fontSize: 9,
          color: PdfColors.blueGrey700,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        titulo,
        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 4),
      pw.Text('Gerado em ${_dataHora(geradoEm)}'),
      pw.Text(detalhe),
      pw.Divider(color: PdfColors.blueGrey300),
    ],
  );

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
