import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/models.dart';
import '../utilities/formatters.dart';

/// Real PDF generation for invoices/quotations, documents and slide decks.
/// Uses the `pdf` + `printing` packages (print, save and share flows).
class PdfService {
  const PdfService._();

  static const _forest = PdfColor.fromInt(0xFF073D2D);
  static const _gold = PdfColor.fromInt(0xFFD5A044);
  static const _grey = PdfColor.fromInt(0xFF6B7A72);

  static Future<void> printInvoice(InvoiceDoc inv) async {
    final bytes = await invoiceBytes(inv);
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: inv.number);
  }

  static Future<void> shareInvoice(InvoiceDoc inv) async {
    final bytes = await invoiceBytes(inv);
    await Printing.sharePdf(bytes: bytes, filename: '${inv.number}.pdf');
  }

  static Future<List<int>> invoiceBytes(InvoiceDoc inv) async {
    final doc = pw.Document();
    final t = inv.totals;
    final title = inv.kind == BillingKind.invoice ? 'INVOICE' : 'QUOTATION';
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ORBITAL OFFICE',
                        style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: _forest)),
                    pw.Text('by ORBITAL.STUDIO.3',
                        style: const pw.TextStyle(fontSize: 9, color: _grey)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(title,
                        style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: _gold)),
                    pw.Text(inv.number, style: const pw.TextStyle(fontSize: 11)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('From', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(inv.businessName.isEmpty ? 'Your Business' : inv.businessName),
                    if (inv.businessAddress.isNotEmpty) pw.Text(inv.businessAddress),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Bill To', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(inv.customerName.isEmpty ? 'Customer' : inv.customerName),
                    if (inv.customerAddress.isNotEmpty) pw.Text(inv.customerAddress),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Issued: ${Formatters.date(inv.issueDate)}'),
                    pw.Text('Due: ${Formatters.date(inv.dueDate)}'),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: ['Description', 'Qty', 'Unit Price', 'Amount'],
              data: [
                for (final i in inv.items)
                  [
                    i.description,
                    Formatters.number(i.quantity),
                    Formatters.money(i.unitPrice, symbol: inv.currencySymbol),
                    Formatters.money(i.asInput.net, symbol: inv.currencySymbol),
                  ],
              ],
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: _forest),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.4),
                3: const pw.FlexColumnWidth(1.4),
              },
            ),
            pw.SizedBox(height: 12),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.SizedBox(
                width: 240,
                child: pw.Column(
                  children: [
                    _row('Subtotal', Formatters.money(t.subtotal, symbol: inv.currencySymbol)),
                    if (t.lineDiscountTotal + t.invoiceDiscountAmount > 0)
                      _row('Discount',
                          '- ${Formatters.money(t.lineDiscountTotal + t.invoiceDiscountAmount, symbol: inv.currencySymbol)}'),
                    if (t.taxAmount > 0)
                      _row(
                          '${inv.taxLabel.isEmpty ? 'Tax' : inv.taxLabel} (${Formatters.number(inv.taxPercent)}%)',
                          Formatters.money(t.taxAmount, symbol: inv.currencySymbol)),
                    pw.Divider(color: _gold),
                    _row('Grand Total',
                        Formatters.money(t.grandTotal, symbol: inv.currencySymbol), bold: true),
                    if (inv.amountPaid > 0) ...[
                      _row('Paid', Formatters.money(t.amountPaid, symbol: inv.currencySymbol)),
                      _row('Balance Due',
                          Formatters.money(t.balanceDue, symbol: inv.currencySymbol), bold: true),
                    ],
                  ],
                ),
              ),
            ),
            if (inv.notes.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Text('Notes', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(inv.notes),
            ],
            pw.Spacer(),
            pw.Center(
              child: pw.Text('Work Smarter. Create Better. — ORBITAL OFFICE',
                  style: const pw.TextStyle(fontSize: 9, color: _grey)),
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }

  static pw.Widget _row(String label, String value, {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: 11,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [pw.Text(label, style: style), pw.Text(value, style: style)],
      ),
    );
  }

  static Future<void> printDocument(OrbitalDocument document) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          pw.Text(document.title,
              style: pw.TextStyle(
                  fontSize: 24, fontWeight: pw.FontWeight.bold, color: _forest)),
          pw.SizedBox(height: 6),
          pw.Divider(color: _gold),
          pw.SizedBox(height: 12),
          for (final block in document.blocks) _blockWidget(block),
        ],
      ),
    );
    final bytes = await doc.save();
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: document.title);
  }

  static pw.Widget _blockWidget(DocBlock block) {
    switch (block.type) {
      case DocBlockType.heading:
        return pw.Padding(
          padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
          child: pw.Text(block.text,
              style: pw.TextStyle(
                  fontSize: 17, fontWeight: pw.FontWeight.bold, color: _forest)),
        );
      case DocBlockType.bulletList:
        return pw.Padding(
          padding: const pw.EdgeInsets.only(left: 12, bottom: 4),
          child: pw.Text('•  ${block.text}', style: const pw.TextStyle(fontSize: 12)),
        );
      case DocBlockType.numberedList:
        return pw.Padding(
          padding: const pw.EdgeInsets.only(left: 12, bottom: 4),
          child: pw.Text(block.text, style: const pw.TextStyle(fontSize: 12)),
        );
      case DocBlockType.table:
        if (block.table.isEmpty) return pw.SizedBox();
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          child: pw.TableHelper.fromTextArray(
            data: block.table,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 10),
          ),
        );
      case DocBlockType.divider:
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 10),
          child: pw.Divider(color: _gold),
        );
      case DocBlockType.image:
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          child: pw.Text('[Image: ${block.text}]',
              style: const pw.TextStyle(fontSize: 10, color: _grey)),
        );
      case DocBlockType.paragraph:
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Text(block.text, style: const pw.TextStyle(fontSize: 12)),
        );
    }
  }

  static Future<void> printPresentation(PresentationDoc deck) async {
    final doc = pw.Document();
    for (final slide in deck.slides) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => pw.Container(
            color: PdfColor.fromInt(slide.background),
            padding: const pw.EdgeInsets.all(28),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(slide.title,
                    style: pw.TextStyle(
                        fontSize: 30,
                        fontWeight: pw.FontWeight.bold,
                        color: _forest)),
                pw.SizedBox(height: 14),
                if (slide.body.isNotEmpty)
                  pw.Text(slide.body, style: const pw.TextStyle(fontSize: 15)),
                for (final b in slide.bullets)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 10, top: 5),
                    child: pw.Text('•  $b', style: const pw.TextStyle(fontSize: 14)),
                  ),
                pw.Spacer(),
                pw.Text(deck.title,
                    style: const pw.TextStyle(fontSize: 9, color: _grey)),
              ],
            ),
          ),
        ),
      );
    }
    final bytes = await doc.save();
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: deck.title);
  }
}
