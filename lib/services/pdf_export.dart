import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/utils/format.dart';
import '../core/utils/jalali.dart' show isoDate;
import '../data/models.dart';
import '../domain/report_models.dart';

/// خروجی PDF فارسی. نکته مهم: برای اتصال حروف فارسی، بسته pdf باید با
/// --dart-define=use_arabic=true ساخته شود (در env/*.json و اسکریپت‌های Build لحاظ شده است).
class PdfExport {
  PdfExport._();
  static pw.Font? _regular;
  static pw.Font? _bold;

  static Future<pw.Document> _newDoc() async {
    if (_regular == null) {
      final r = await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf');
      final b = await rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf');
      _regular = pw.Font.ttf(r);
      _bold = pw.Font.ttf(b);
    }
    return pw.Document(
      theme: pw.ThemeData.withFont(base: _regular, bold: _bold),
    );
  }

  static pw.Widget _t(
    String text, {
    bool bold = false,
    double size = 10,
    pw.TextAlign align = pw.TextAlign.right,
    PdfColor? color,
  }) => pw.Text(
    text,
    textAlign: align,
    textDirection: pw.TextDirection.rtl,
    style: pw.TextStyle(
      fontSize: size,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color,
    ),
  );

  static pw.Widget _cell(
    String text, {
    bool bold = false,
    double size = 9.5,
    pw.TextAlign align = pw.TextAlign.right,
    PdfColor? color,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
    child: _t(text, bold: bold, size: size, align: align, color: color),
  );

  /// جدول راست‌به‌چپ: ستون اول منطقی در سمت راست می‌نشیند (Table در pdf جهت صفحه را رعایت نمی‌کند؛ ترتیب را خودمان برعکس می‌کنیم)
  static pw.Widget _table({
    required List<String> headers,
    required List<List<String>> rows,
    required List<double> flex,
    required List<bool> numeric,
    List<String>? totals,
    double fontSize = 9.5,
  }) {
    final n = headers.length;
    final order = [for (var i = n - 1; i >= 0; i--) i]; // راست‌به‌چپ
    final widths = <int, pw.TableColumnWidth>{
      for (var k = 0; k < n; k++) k: pw.FlexColumnWidth(flex[order[k]]),
    };
    pw.TableRow rowOf(
      List<String> cells, {
      bool header = false,
      bool total = false,
    }) => pw.TableRow(
      decoration: header || total
          ? const pw.BoxDecoration(color: PdfColors.blueGrey50)
          : null,
      children: [
        for (final i in order)
          _cell(
            i < cells.length ? cells[i] : '',
            bold: header || total,
            size: fontSize,
            align: header
                ? pw.TextAlign.center
                : (numeric[i] ? pw.TextAlign.left : pw.TextAlign.right),
          ),
      ],
    );
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: widths,
      children: [
        rowOf(headers, header: true),
        for (final r in rows) rowOf(r),
        if (totals != null) rowOf(totals, total: true),
      ],
    );
  }

  // ---------------- فاکتور ----------------
  static Future<Uint8List> invoice(
    InvoiceDetail d, {
    required Map<String, String> business,
    String partyMobile = '',
  }) async {
    final doc = await _newDoc();
    final s = d.summary;
    final title = s.isSale ? 'فاکتور فروش' : 'فاکتور خرید / هزینه';
    final biz = (business['name'] ?? '').trim();
    final lines = [for (var i = 0; i < d.lines.length; i++) d.lines[i]];
    final rows = <List<String>>[
      for (var i = 0; i < lines.length; i++)
        [
          faDigits(i + 1),
          lines[i].title,
          fmtQty(lines[i].qty),
          fmtMoney(lines[i].unitPrice),
          fmtMoney(lines[i].discount),
          fmtMoney(lines[i].lineTotal),
        ],
    ];

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(30),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.center,
          child: _t(
            (business['footer'] ?? '').trim(),
            size: 9,
            color: PdfColors.grey600,
            align: pw.TextAlign.center,
          ),
        ),
        build: (ctx) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (biz.isNotEmpty) _t(biz, bold: true, size: 16),
                  if ((business['phone'] ?? '').isNotEmpty)
                    _t('تلفن: ${faDigits(business['phone'])}', size: 9.5),
                  if ((business['address'] ?? '').isNotEmpty)
                    _t(business['address']!, size: 9.5),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _t(title, bold: true, size: 15),
                  _t('شماره: ${faDigits(s.number)}', size: 10.5),
                  _t('تاریخ: ${fmtJalali(s.date)}', size: 10.5),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(thickness: 0.8, color: PdfColors.grey600),
          pw.SizedBox(height: 6),
          _t(
            '${s.isSale ? 'مشتری' : 'طرف‌حساب'}: ${s.partyName.isEmpty ? 'متفرقه' : s.partyName}${partyMobile.isNotEmpty ? '   موبایل: ${faDigits(partyMobile)}' : ''}',
            size: 11,
            bold: true,
          ),
          if ((s.description ?? '').isNotEmpty)
            _t('توضیحات: ${s.description}', size: 9.5),
          pw.SizedBox(height: 10),
          _table(
            headers: const [
              'ردیف',
              'شرح',
              'تعداد',
              'قیمت واحد',
              'تخفیف',
              'مبلغ',
            ],
            rows: rows,
            flex: const [0.6, 3.4, 1, 1.6, 1.3, 1.7],
            numeric: const [false, false, true, true, true, true],
          ),
          pw.SizedBox(height: 10),
          pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Container(
              width: 230,
              child: _table(
                headers: const ['شرح', 'مبلغ (تومان)'],
                rows: [
                  ['جمع کل', fmtMoney(s.total)],
                  ['پرداخت‌شده', fmtMoney(s.paid)],
                  ['باقی‌مانده', fmtMoney(s.remaining)],
                ],
                flex: const [1.2, 1.6],
                numeric: const [false, true],
              ),
            ),
          ),
          if (d.payments.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _t('پرداخت‌ها', bold: true, size: 11),
            pw.SizedBox(height: 4),
            _table(
              headers: const ['تاریخ', 'روش', 'مبلغ'],
              rows: [
                for (final p in d.payments)
                  [
                    fmtJalali(p.date),
                    kMethodLabels[p.method] ?? p.method,
                    fmtMoney(p.amount),
                  ],
              ],
              flex: const [1.2, 1.2, 1.4],
              numeric: const [false, false, true],
            ),
          ],
        ],
      ),
    );
    return doc.save();
  }

  // ---------------- گزارش ----------------
  static Future<Uint8List> report(ReportTable t) async {
    final doc = await _newDoc();
    final wide = t.columns.length > 5;
    final headers = [for (final c in t.columns) c.title];
    final rows = [
      for (final r in t.rows)
        [
          for (var i = 0; i < t.columns.length; i++)
            formatCell(t.columns[i], i < r.length ? r[i] : null),
        ],
    ];
    final totals = t.totals == null
        ? null
        : [
            for (var i = 0; i < t.columns.length; i++)
              formatCell(t.columns[i], t.totals![i]),
          ];
    final flex = [
      for (final c in t.columns)
        switch (c.type) {
          ColType.text => 2.4,
          ColType.money => 1.5,
          ColType.date => 1.2,
          _ => 1.0,
        },
    ];
    final numeric = [
      for (final c in t.columns)
        c.type == ColType.money ||
            c.type == ColType.qty ||
            c.type == ColType.count,
    ];

    doc.addPage(
      pw.MultiPage(
        pageFormat: wide ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(28),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.center,
          child: _t(
            'تاریخ تهیه : ${fmtJalali(isoDate(DateTime.now()))}',
            size: 8.5,
            color: PdfColors.grey600,
            align: pw.TextAlign.center,
          ),
        ),
        build: (ctx) => [
          _t(t.title, bold: true, size: 16),
          if (t.subtitle.isNotEmpty)
            _t(t.subtitle, size: 9.5, color: PdfColors.grey600),
          pw.SizedBox(height: 10),
          _table(
            headers: headers,
            rows: rows,
            flex: flex,
            numeric: numeric,
            totals: totals,
            fontSize: 8.8,
          ),
        ],
      ),
    );
    return doc.save();
  }
}
