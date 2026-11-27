import 'dart:typed_data';

import '../domain/report_models.dart';
import 'xlsx_writer.dart';

/// جدول گزارش ← فایل Excel. مبلغ‌ها عددی (قابل جمع در Excel) و تاریخ‌ها شمسی متنی هستند.
Uint8List reportToXlsx(ReportTable t) {
  final rows = <List<XCell>>[
    [XCell.text(t.title, XStyle.title)],
    if (t.subtitle.isNotEmpty) [XCell.text(t.subtitle, XStyle.subtitle)],
    [],
  ];
  final headerRow = rows.length;
  rows.add([for (final c in t.columns) XCell.text(c.title, XStyle.header)]);

  XCell cell(ReportColumn c, Object? v, {bool total = false}) {
    if (v == null || (v is String && v.isEmpty)) {
      return XCell.empty(total ? XStyle.totalText : XStyle.normal);
    }
    switch (c.type) {
      case ColType.money:
        return v is num
            ? XCell.number(v, total ? XStyle.totalMoney : XStyle.money)
            : XCell.text('$v', total ? XStyle.totalText : XStyle.normal);
      case ColType.qty:
        return v is num ? XCell.number(v / 1000, XStyle.qty) : XCell.text('$v');
      case ColType.count:
        return v is num
            ? XCell.number(v, total ? XStyle.totalMoney : XStyle.money)
            : XCell.text('$v', total ? XStyle.totalText : XStyle.normal);
      default:
        return XCell.text(
          formatCell(c, v),
          total ? XStyle.totalText : XStyle.normal,
        );
    }
  }

  for (var r = 0; r < t.rows.length; r++) {
    final bold = t.boldRows.contains(r);
    rows.add([
      for (var i = 0; i < t.columns.length; i++)
        bold && t.rows[r][i] is! num
            ? XCell.text(
                formatCell(t.columns[i], t.rows[r][i]),
                XStyle.totalText,
              )
            : cell(t.columns[i], t.rows[r][i], total: bold),
    ]);
  }
  if (t.totals != null) {
    rows.add([
      for (var i = 0; i < t.columns.length; i++)
        cell(t.columns[i], t.totals![i], total: true),
    ]);
  }
  final widths = [
    for (final c in t.columns)
      switch (c.type) {
        ColType.text => 28.0,
        ColType.money => 16.0,
        ColType.qty => 12.0,
        ColType.date => 13.0,
        _ => 12.0,
      },
  ];
  return buildXlsx(
    XSheet(
      name: t.title,
      rows: rows,
      columnWidths: widths,
      freezeRows: headerRow + 1,
    ),
  );
}
