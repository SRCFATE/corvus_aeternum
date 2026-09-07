import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/manuscript.dart';
import 'win_ansi.dart';

/// Maqueta el manuscrito en PDF.
///
/// A diferencia de DOCX y EPUB —que son texto marcado y el lector decide cómo
/// se ve—, aquí Corvus decide la página: tipografía, interlineado, márgenes,
/// numeración y encabezado. Por eso es el único formato que necesita un motor
/// de maquetación y no basta con empaquetar XML.
///
/// Se usa Times y no Helvetica porque un manuscrito de ficción se lee en serifa
/// y porque las fuentes estándar del PDF cubren el español completo —acentos,
/// eñes, signos de apertura, comillas angulares y rayas de diálogo— sin tener
/// que incrustar un archivo de tipografía y triplicar el peso del documento.
class PdfExporter {
  Future<Uint8List> build(ManuscriptDocument doc) async {
    final documento = pw.Document(
      title: toWinAnsi(doc.title),
      author: toWinAnsi(doc.author.isEmpty ? 'Corvus Atelier' : doc.author),
      subject: toWinAnsi(doc.synopsis),
      creator: 'Corvus Atelier',
    );

    final tema = pw.ThemeData.withFont(
      base: pw.Font.times(),
      bold: pw.Font.timesBold(),
      italic: pw.Font.timesItalic(),
      boldItalic: pw.Font.timesBoldItalic(),
    );

    documento.addPage(_portada(doc, tema));

    if (!doc.frontMatter.isEmpty) {
      documento.addPage(_cortesia(doc, tema));
    }

    documento.addPage(_cuerpo(doc, tema));

    return documento.save();
  }

  static const _margen = 2.54 * PdfPageFormat.cm; // Una pulgada.

  pw.Page _portada(ManuscriptDocument doc, pw.ThemeData tema) {
    return pw.Page(
      pageFormat: PdfPageFormat.letter,
      theme: tema,
      margin: const pw.EdgeInsets.all(_margen),
      build: (context) => pw.Center(
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              toWinAnsi(doc.title),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
            ),
            if (doc.author.isNotEmpty) ...[
              pw.SizedBox(height: 18),
              pw.Text(toWinAnsi(doc.author), style: const pw.TextStyle(fontSize: 14)),
            ],
            if (doc.genre.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Text(
                toWinAnsi(doc.genre),
                style: pw.TextStyle(
                  fontSize: 11,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey700,
                ),
              ),
            ],
            pw.SizedBox(height: 34),
            pw.Text(
              toWinAnsi('${doc.wordCount} palabras · ${doc.chapters.length} capítulos'),
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            if (doc.synopsis.isNotEmpty) ...[
              pw.SizedBox(height: 40),
              pw.Container(
                width: 340,
                child: pw.Text(
                  toWinAnsi(doc.synopsis),
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 10.5,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey800,
                    lineSpacing: 3,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  pw.Page _cortesia(ManuscriptDocument doc, pw.ThemeData tema) {
    final front = doc.frontMatter;

    return pw.Page(
      pageFormat: PdfPageFormat.letter,
      theme: tema,
      margin: const pw.EdgeInsets.all(_margen),
      build: (context) => pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (front.copyrightNotice.isNotEmpty)
            pw.Text(
              toWinAnsi(front.copyrightNotice),
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 10, lineSpacing: 3),
            ),
          if (front.publisher.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text(toWinAnsi(front.publisher), style: const pw.TextStyle(fontSize: 10)),
          ],
          if (front.isbn.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text(toWinAnsi('ISBN: ${front.isbn}'),
                style: const pw.TextStyle(fontSize: 10)),
          ],
          if (front.dedication.isNotEmpty) ...[
            pw.SizedBox(height: 60),
            pw.Text(
              toWinAnsi(front.dedication),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 12,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  pw.MultiPage _cuerpo(ManuscriptDocument doc, pw.ThemeData tema) {
    return pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      theme: tema,
      margin: const pw.EdgeInsets.all(_margen),
      // El tope por defecto son 20 páginas; una novela lo rebasa en el primer
      // capítulo.
      maxPages: 5000,
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(bottom: 14),
              child: pw.Text(
                toWinAnsi(doc.author.isEmpty
                    ? doc.title
                    : '${doc.author} · ${doc.title}'),
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: PdfColors.grey600,
                ),
              ),
            ),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.center,
        margin: const pw.EdgeInsets.only(top: 12),
        child: pw.Text(
          '${context.pageNumber}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ),
      build: (context) => [
        for (var i = 0; i < doc.chapters.length; i++) ...[
          // Cada capítulo empieza en página nueva, salvo el primero, que ya
          // la estrena por ser el comienzo del cuerpo.
          if (i > 0) pw.NewPage(),
          pw.Header(
            level: 0,
            child: pw.Container(
              alignment: pw.Alignment.center,
              margin: const pw.EdgeInsets.only(top: 24, bottom: 22),
              child: pw.Text(
                toWinAnsi(doc.chapters[i].title),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
          ..._parrafos(doc.chapters[i]),
        ],
        if (doc.frontMatter.acknowledgements.isNotEmpty) ...[
          pw.NewPage(),
          pw.Container(
            alignment: pw.Alignment.center,
            margin: const pw.EdgeInsets.only(top: 24, bottom: 22),
            child: pw.Text(
              toWinAnsi('Agradecimientos'),
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Paragraph(
            text: toWinAnsi(doc.frontMatter.acknowledgements),
            style: const pw.TextStyle(fontSize: 11.5, lineSpacing: 5),
          ),
        ],
      ],
    );
  }

  List<pw.Widget> _parrafos(ManuscriptChapter capitulo) {
    final parrafos = capitulo.paragraphs;

    return [
      for (var i = 0; i < parrafos.length; i++)
        pw.Container(
          width: double.infinity,
          padding: pw.EdgeInsets.only(
            // El primer párrafo de un capítulo no lleva sangría.
            left: i == 0 ? 0 : 18,
            bottom: 4,
          ),
          child: pw.Text(
            toWinAnsi(parrafos[i]),
            textAlign: pw.TextAlign.justify,
            style: const pw.TextStyle(fontSize: 11.5, lineSpacing: 5),
          ),
        ),
    ];
  }
}
