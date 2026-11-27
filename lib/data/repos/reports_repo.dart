import '../../core/utils/format.dart';
import '../../core/utils/jalali.dart';
import '../../domain/periods.dart';
import '../../domain/report_models.dart';
import '../database.dart';
import '../models.dart';
import '../queries.dart';

class DashboardData {
  final int todaySales;
  final int todayReceived;
  final int monthSales;
  final int monthReceived;
  final int monthExpenses;
  final int monthProfit;
  final int saleInvoicesTotal;
  final int saleInvoicesMonth;
  final int customers;
  final int unsettledCount;
  final int unsettledRemaining;
  final int customersDebt;
  final ChartData chart;
  const DashboardData({
    required this.todaySales,
    required this.todayReceived,
    required this.monthSales,
    required this.monthReceived,
    required this.monthExpenses,
    required this.monthProfit,
    required this.saleInvoicesTotal,
    required this.saleInvoicesMonth,
    required this.customers,
    required this.unsettledCount,
    required this.unsettledRemaining,
    required this.customersDebt,
    required this.chart,
  });
}

class ReportsRepo {
  final AppDatabase db;
  ReportsRepo(this.db);

  static int _i(Object? v) => (v as int?) ?? 0;

  // ---------- جمع‌ها ----------
  Totals totals(DateRange r, {int? partyId, int? itemId}) {
    final a = [r.fromIso, r.toIso, partyId, partyId, itemId, itemId];
    var inv = 0, sales = 0, disc = 0, cogs = 0;
    for (final x in db.query(qSalesByDay, a)) {
      inv += _i(x['cnt']);
      sales += _i(x['amount']);
      disc += _i(x['discount']);
      cogs += _i(x['cogs']);
    }
    final exp = db
        .query(qExpensesByDay, a)
        .fold<int>(0, (s, x) => s + _i(x['amount']));
    final goods = db
        .query(qGoodsPurchasesByDay, a)
        .fold<int>(0, (s, x) => s + _i(x['amount']));
    var cin = 0, cout = 0;
    for (final x in db.query(qCashByDay, [
      r.fromIso,
      r.toIso,
      partyId,
      partyId,
    ])) {
      if (x['dir'] == 'in') {
        cin += _i(x['amount']);
      } else {
        cout += _i(x['amount']);
      }
    }
    return Totals(
      invoiceCount: inv,
      sales: sales,
      discounts: disc,
      cogs: cogs,
      expenses: exp,
      goodsPurchases: goods,
      cashIn: cin,
      cashOut: cout,
    );
  }

  // ---------- داشبورد ----------
  DashboardData dashboard([DateTime? now]) {
    final n = now ?? DateTime.now();
    final today = totals(DateRange.today(n));
    final month = totals(DateRange.thisJalaliMonth(n));
    final un = db.one(qUnsettledSummary)!;
    final customers = db.intScalar(
      "SELECT COUNT(*) FROM parties WHERE kind='customer' AND deleted_at IS NULL",
    );
    var debt = 0;
    for (final x in db.query(qPartiesWithBalance, [
      'customer',
      '',
      '',
      '',
      '',
    ])) {
      final b = _i(x['total_amount']) - _i(x['paid_amount']);
      if (b > 0) debt += b;
    }
    // نمودار ۶ ماه شمسی اخیر: درآمد (فروش) در برابر هزینه (بهای تمام‌شده + هزینه‌ها)
    final j = Jalali.fromDate(n);
    final labels = <String>[], income = <double>[], cost = <double>[];
    for (var k = 5; k >= 0; k--) {
      var m = j.month - k, y = j.year;
      while (m < 1) {
        m += 12;
        y--;
      }
      final t = totals(DateRange.jalaliMonth(y, m));
      labels.add(Jalali.monthNames[m]);
      income.add(t.sales.toDouble());
      cost.add((t.cogs + t.expenses).toDouble());
    }
    return DashboardData(
      todaySales: today.sales,
      todayReceived: today.cashIn,
      monthSales: month.sales,
      monthReceived: month.cashIn,
      monthExpenses: month.expenses,
      monthProfit: month.netProfit,
      saleInvoicesTotal: db.intScalar(
        "SELECT COUNT(*) FROM invoices WHERE kind='sale' AND deleted_at IS NULL",
      ),
      saleInvoicesMonth: month.invoiceCount,
      customers: customers,
      unsettledCount: _i(un['cnt']),
      unsettledRemaining: _i(un['remaining']),
      customersDebt: debt,
      chart: ChartData('درآمد و هزینه ۶ ماه اخیر', labels, [
        ChartSeries('درآمد (فروش)', income),
        ChartSeries('هزینه (بهای تمام‌شده + هزینه‌ها)', cost),
      ]),
    );
  }

  String _sub(DateRange r) =>
      'از ${fmtJalali(r.fromIso)} تا ${fmtJalali(r.toIso)}';

  // ---------- ۱ تا ۴: درآمد روزانه/هفتگی/ماهانه/سالانه ----------
  ReportTable periodReport(
    DateRange r,
    Granularity g, {
    int? partyId,
    int? itemId,
  }) {
    final a = [r.fromIso, r.toIso, partyId, partyId, itemId, itemId];
    final acc =
        <String, List<int>>{}; // key -> [cnt, sales, disc, cogs, exp, in, out]
    final labels = <String, String>{};
    List<int> slot(String iso) {
      final p = periodOf(parseIso(iso)!, g);
      labels[p.key] = p.label;
      return acc.putIfAbsent(p.key, () => List<int>.filled(7, 0));
    }

    for (final x in db.query(qSalesByDay, a)) {
      final s = slot(x['d'] as String);
      s[0] += _i(x['cnt']);
      s[1] += _i(x['amount']);
      s[2] += _i(x['discount']);
      s[3] += _i(x['cogs']);
    }
    for (final x in db.query(qExpensesByDay, a)) {
      slot(x['d'] as String)[4] += _i(x['amount']);
    }
    for (final x in db.query(qCashByDay, [
      r.fromIso,
      r.toIso,
      partyId,
      partyId,
    ])) {
      slot(x['d'] as String)[x['dir'] == 'in' ? 5 : 6] += _i(x['amount']);
    }
    final keys = acc.keys.toList()..sort();
    final rows = <List<Object?>>[];
    final tot = List<int>.filled(7, 0);
    for (final k in keys) {
      final s = acc[k]!;
      for (var i = 0; i < 7; i++) {
        tot[i] += s[i];
      }
      rows.add([
        labels[k],
        s[0],
        s[1],
        s[2],
        s[5],
        s[6],
        s[3],
        s[4],
        s[1] - s[3] - s[4],
      ]);
    }
    final chartKeys = keys.length > 40 ? keys.sublist(keys.length - 40) : keys;
    return ReportTable(
      title: 'درآمد ${granularityLabel(g)}',
      subtitle: _sub(r),
      columns: const [
        ReportColumn('دوره', ColType.text),
        ReportColumn('تعداد فاکتور', ColType.count),
        ReportColumn('فروش', ColType.money),
        ReportColumn('تخفیف', ColType.money),
        ReportColumn('دریافتی', ColType.money),
        ReportColumn('پرداختی', ColType.money),
        ReportColumn('بهای تمام‌شده', ColType.money),
        ReportColumn('هزینه', ColType.money),
        ReportColumn('سود', ColType.money),
      ],
      rows: rows,
      totals: [
        'جمع',
        tot[0],
        tot[1],
        tot[2],
        tot[5],
        tot[6],
        tot[3],
        tot[4],
        tot[1] - tot[3] - tot[4],
      ],
      chart: ChartData(
        'فروش و دریافتی',
        [for (final k in chartKeys) labels[k]!],
        [
          ChartSeries('فروش', [
            for (final k in chartKeys) acc[k]![1].toDouble(),
          ]),
          ChartSeries('دریافتی', [
            for (final k in chartKeys) acc[k]![5].toDouble(),
          ]),
        ],
      ),
    );
  }

  // ---------- ۵: سود و زیان ----------
  ReportTable profitLoss(DateRange r, {int? partyId, int? itemId}) {
    final t = totals(r, partyId: partyId, itemId: itemId);
    final eb = db.query(qExpenseBreakdown, [
      r.fromIso,
      r.toIso,
      partyId,
      partyId,
      itemId,
      itemId,
    ]);
    final rows = <List<Object?>>[];
    final bold = <int>[];
    void add(String t, int v, {bool b = false}) {
      if (b) bold.add(rows.length);
      rows.add([t, v]);
    }

    add('فروش (کالا و خدمات)', t.sales, b: true);
    add('   تخفیف‌های اعمال‌شده (اطلاعاتی، از فروش کسر شده)', t.discounts);
    add('بهای تمام‌شده کالاهای فروخته‌شده', -t.cogs);
    add('سود ناخالص', t.grossProfit, b: true);
    for (final e in eb) {
      add('   هزینه: ${e['title']}', -_i(e['amount']));
    }
    add('جمع هزینه‌ها', -t.expenses);
    add('سود (زیان) خالص', t.netProfit, b: true);
    add('— اطلاعات جانبی (در سود محاسبه نمی‌شوند) —', 0);
    add('   خرید کالا (موجودی انبار)', t.goodsPurchases);
    add('   وجه دریافتی', t.cashIn);
    add('   وجه پرداختی', t.cashOut);
    add(
      '   فروش اعتباری باقی‌مانده در بازه (فروش − دریافتی)',
      t.sales - t.cashIn,
    );
    return ReportTable(
      title: 'سود و زیان',
      subtitle: '${_sub(r)} — بهای تمام‌شده بر اساس آخرین قیمت خرید ثبت‌شده',
      columns: const [
        ReportColumn('شرح', ColType.text),
        ReportColumn('مبلغ (تومان)', ColType.money),
      ],
      rows: rows,
      boldRows: bold,
    );
  }

  // ---------- ۶ تا ۹: فروش کالا/خدمات و پرفروش‌ها ----------
  ReportTable itemSales(
    DateRange r, {
    required bool products,
    int? partyId,
    int? itemId,
    int? top,
  }) {
    final kinds = products ? ['product', 'product'] : ['service', 'free'];
    var data = db.query(qItemSales, [
      r.fromIso,
      r.toIso,
      ...kinds,
      partyId,
      partyId,
      itemId,
      itemId,
    ]);
    if (top != null && data.length > top) data = data.sublist(0, top);
    final rows = <List<Object?>>[];
    var q = 0, amt = 0, cg = 0, inv = 0;
    for (final x in data) {
      final cogs = _i(x['cogs']);
      rows.add([
        x['code'],
        x['name'],
        x['qty_milli'],
        x['amount'],
        cogs,
        _i(x['amount']) - cogs,
        x['invoices'],
      ]);
      q += _i(x['qty_milli']);
      amt += _i(x['amount']);
      cg += cogs;
      inv += _i(x['invoices']);
    }
    final title = top == null
        ? (products ? 'مجموع فروش کالا' : 'مجموع فروش خدمات')
        : (products ? 'پرفروش‌ترین کالاها' : 'پرفروش‌ترین خدمات');
    final shown = data.take(10).toList();
    return ReportTable(
      title: title,
      subtitle: _sub(r),
      columns: const [
        ReportColumn('کد', ColType.text),
        ReportColumn('نام', ColType.text),
        ReportColumn('تعداد', ColType.qty),
        ReportColumn('مبلغ فروش', ColType.money),
        ReportColumn('بهای تمام‌شده', ColType.money),
        ReportColumn('سود ناخالص', ColType.money),
        ReportColumn('تعداد فاکتور', ColType.count),
      ],
      rows: rows,
      totals: ['', 'جمع', q, amt, cg, amt - cg, inv],
      chart: ChartData(
        title,
        [for (final x in shown) '${x['name']}'],
        [
          ChartSeries('مبلغ فروش', [
            for (final x in shown) _i(x['amount']).toDouble(),
          ]),
        ],
      ),
    );
  }

  // ---------- ۱۰: هزینه‌ها ----------
  ReportTable expenses(
    DateRange r, {
    int? partyId,
    int? itemId,
    int limit = 2000,
  }) {
    final a = [r.fromIso, r.toIso, partyId, partyId, itemId, itemId];
    final data = db.query(qExpenseDetails, [...a, limit]);
    final eb = db.query(qExpenseBreakdown, a).take(10).toList();
    var sum = 0;
    final rows = <List<Object?>>[];
    for (final x in data) {
      sum += _i(x['amount']);
      rows.add([
        x['date'],
        x['number'],
        x['party'],
        x['title'],
        x['qty_milli'],
        x['unit_price'],
        x['discount'],
        x['amount'],
      ]);
    }
    return ReportTable(
      title: 'گزارش هزینه‌ها',
      subtitle:
          '${_sub(r)} — فقط خرید خدمات و هزینه‌ها (خرید کالا هزینه حساب نمی‌شود)',
      columns: const [
        ReportColumn('تاریخ', ColType.date),
        ReportColumn('شماره فاکتور', ColType.count),
        ReportColumn('طرف‌حساب', ColType.text),
        ReportColumn('شرح', ColType.text),
        ReportColumn('تعداد', ColType.qty),
        ReportColumn('قیمت واحد', ColType.money),
        ReportColumn('تخفیف', ColType.money),
        ReportColumn('مبلغ', ColType.money),
      ],
      rows: rows,
      totals: ['', '', '', 'جمع', '', '', '', sum],
      chart: ChartData(
        'هزینه‌ها بر اساس شرح',
        [for (final x in eb) '${x['title']}'],
        [
          ChartSeries('مبلغ', [for (final x in eb) _i(x['amount']).toDouble()]),
        ],
      ),
    );
  }

  // ---------- ۱۱: پرداخت‌ها ----------
  ReportTable payments(
    DateRange r, {
    int? partyId,
    String method = '',
    String direction = '',
    int limit = 2000,
  }) {
    final data = db.query(qPaymentsReport, [
      r.fromIso,
      r.toIso,
      partyId,
      partyId,
      method,
      method,
      direction,
      direction,
      limit,
    ]);
    var cin = 0, cout = 0;
    final rows = <List<Object?>>[];
    for (final x in data) {
      if (x['direction'] == 'in') {
        cin += _i(x['amount']);
      } else {
        cout += _i(x['amount']);
      }
      rows.add([
        x['date'],
        x['party'],
        x['inv_number'],
        x['direction'],
        x['method'],
        x['amount'],
        x['description'],
      ]);
    }
    return ReportTable(
      title: 'گزارش پرداخت‌ها',
      subtitle:
          '${_sub(r)} — جمع دریافتی: ${fmtToman(cin)} ، جمع پرداختی: ${fmtToman(cout)}',
      columns: const [
        ReportColumn('تاریخ', ColType.date),
        ReportColumn('طرف‌حساب', ColType.text),
        ReportColumn('فاکتور', ColType.count),
        ReportColumn('جهت', ColType.direction),
        ReportColumn('روش', ColType.method),
        ReportColumn('مبلغ', ColType.money),
        ReportColumn('توضیح', ColType.text),
      ],
      rows: rows,
    );
  }

  // ---------- ۱۲: بدهی مشتریان ----------
  ReportTable receivables({String kind = 'customer', bool credit = false}) {
    final rows = <List<Object?>>[];
    var sum = 0;
    final data =
        db
            .query(qPartiesWithBalance, [kind, '', '', '', ''])
            .map(Party.fromRow)
            .where((p) => credit ? p.balance < 0 : p.balance > 0)
            .toList()
          ..sort(
            (a, b) => credit
                ? a.balance.compareTo(b.balance)
                : b.balance.compareTo(a.balance),
          );
    for (final p in data) {
      final b = credit ? -p.balance : p.balance;
      sum += b;
      rows.add([
        p.code,
        p.name,
        p.mobile ?? '',
        p.totalAmount,
        p.paidAmount,
        b,
      ]);
    }
    final isC = kind == 'customer';
    return ReportTable(
      title: credit
          ? (isC ? 'بستانکاری مشتریان' : 'مطالبه از تأمین‌کنندگان')
          : (isC ? 'بدهی مشتریان' : 'بدهی به تأمین‌کنندگان'),
      subtitle: 'تا امروز، ${fmtJalali(isoDate(DateTime.now()))}',
      columns: [
        const ReportColumn('کد', ColType.text),
        const ReportColumn('نام', ColType.text),
        const ReportColumn('موبایل', ColType.text),
        ReportColumn(isC ? 'جمع فاکتورها' : 'جمع خریدها', ColType.money),
        ReportColumn(isC ? 'جمع دریافتی' : 'جمع پرداختی', ColType.money),
        ReportColumn(credit ? 'مبلغ بستانکاری' : 'مانده بدهی', ColType.money),
      ],
      rows: rows,
      totals: ['', 'جمع', '', '', '', sum],
    );
  }

  // ---------- ۱۳: فاکتورهای تسویه‌نشده ----------
  ReportTable unsettled(
    DateRange r, {
    String kind = 'sale',
    int? partyId,
    int limit = 2000,
  }) {
    final data = db.query(qUnsettledInvoices, [
      kind,
      r.fromIso,
      r.toIso,
      partyId,
      partyId,
      limit,
    ]);
    final rows = <List<Object?>>[];
    var t = 0, p = 0;
    for (final x in data) {
      t += _i(x['total']);
      p += _i(x['paid']);
      rows.add([
        x['number'],
        x['date'],
        x['party'],
        x['total'],
        x['paid'],
        _i(x['total']) - _i(x['paid']),
      ]);
    }
    return ReportTable(
      title: kind == 'sale'
          ? 'فاکتورهای فروش تسویه‌نشده'
          : 'فاکتورهای خرید تسویه‌نشده',
      subtitle: _sub(r),
      columns: const [
        ReportColumn('شماره', ColType.count),
        ReportColumn('تاریخ', ColType.date),
        ReportColumn('طرف‌حساب', ColType.text),
        ReportColumn('مبلغ فاکتور', ColType.money),
        ReportColumn('پرداخت‌شده', ColType.money),
        ReportColumn('مانده', ColType.money),
      ],
      rows: rows,
      totals: ['', '', 'جمع', t, p, t - p],
    );
  }
}
