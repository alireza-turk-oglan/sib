import '../core/utils/format.dart';
import '../data/models.dart';

enum ColType { text, money, qty, count, date, method, direction }

class ReportColumn {
  final String title;
  final ColType type;
  const ReportColumn(this.title, this.type);
}

class ChartSeries {
  final String name;
  final List<double> values;
  const ChartSeries(this.name, this.values);
}

class ChartData {
  final String title;
  final List<String> labels;
  final List<ChartSeries> series;
  const ChartData(this.title, this.labels, this.series);
  bool get isEmpty =>
      labels.isEmpty || series.every((s) => s.values.every((v) => v == 0));
}

/// خروجی عمومی همه گزارش‌ها؛ هم جدول UI و هم PDF/Excel از همین ساخته می‌شوند.
class ReportTable {
  final String title;
  final String subtitle;
  final List<ReportColumn> columns;
  final List<List<Object?>> rows;
  final List<Object?>? totals;
  final List<int> boldRows;
  final ChartData? chart;
  const ReportTable({
    required this.title,
    this.subtitle = '',
    required this.columns,
    required this.rows,
    this.totals,
    this.boldRows = const [],
    this.chart,
  });
}

/// نمایش یک سلول با ارقام فارسی
String formatCell(ReportColumn col, Object? v) {
  if (v == null) return '';
  switch (col.type) {
    case ColType.text:
      return '$v';
    case ColType.money:
      return v is num ? fmtMoney(v) : '$v';
    case ColType.qty:
      return v is num ? fmtQty(v / 1000) : '$v';
    case ColType.count:
      return faDigits(v);
    case ColType.date:
      return fmtJalali('$v');
    case ColType.method:
      return kMethodLabels['$v'] ?? '$v';
    case ColType.direction:
      return v == 'in' ? 'دریافت' : (v == 'out' ? 'پرداخت' : '$v');
  }
}

/// جمع‌های مالی یک بازه (همگی تفکیک‌شده)
class Totals {
  final int invoiceCount;
  final int sales;
  final int discounts;
  final int cogs;
  final int expenses;
  final int goodsPurchases;
  final int cashIn;
  final int cashOut;
  const Totals({
    this.invoiceCount = 0,
    this.sales = 0,
    this.discounts = 0,
    this.cogs = 0,
    this.expenses = 0,
    this.goodsPurchases = 0,
    this.cashIn = 0,
    this.cashOut = 0,
  });
  int get grossProfit => sales - cogs;
  int get netProfit => sales - cogs - expenses;
}
