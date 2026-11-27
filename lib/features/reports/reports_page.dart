import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/jalali.dart';
import '../../core/widgets/bar_chart.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/jalali_picker.dart';
import '../../core/widgets/report_grid.dart';
import '../../data/models.dart';
import '../../data/repos/reports_repo.dart';
import '../../domain/periods.dart';
import '../../domain/report_models.dart';
import '../../services/file_service.dart';
import '../../services/pdf_export.dart';
import '../../services/report_export.dart';

enum _PartyScope { none, customer, supplier, any }

class _Params {
  DateRange range = DateRange.thisJalaliMonth();
  int? partyId;
  int? itemId;
  String method = '';
  String direction = '';
  String invKind = 'sale';
  bool credit = false;
  String partyKind = 'customer';
}

class _Def {
  final String title;
  final String group;
  final bool usesRange;
  final _PartyScope party;
  final String itemKind; // '' = بدون فیلتر کالا ، 'all' ، 'product' ، 'service'
  final bool payFilters;
  final bool unsettledKind;
  final bool receivable;
  final ReportTable Function(ReportsRepo r, _Params p) build;
  const _Def(
    this.title,
    this.group,
    this.build, {
    this.usesRange = true,
    this.party = _PartyScope.none,
    this.itemKind = '',
    this.payFilters = false,
    this.unsettledKind = false,
    this.receivable = false,
  });
}

final List<_Def> _defs = [
  _Def(
    'درآمد روزانه',
    'درآمد و سود',
    (r, p) => r.periodReport(
      p.range,
      Granularity.day,
      partyId: p.partyId,
      itemId: p.itemId,
    ),
    party: _PartyScope.any,
    itemKind: 'all',
  ),
  _Def(
    'درآمد هفتگی',
    'درآمد و سود',
    (r, p) => r.periodReport(
      p.range,
      Granularity.week,
      partyId: p.partyId,
      itemId: p.itemId,
    ),
    party: _PartyScope.any,
    itemKind: 'all',
  ),
  _Def(
    'درآمد ماهانه',
    'درآمد و سود',
    (r, p) => r.periodReport(
      p.range,
      Granularity.month,
      partyId: p.partyId,
      itemId: p.itemId,
    ),
    party: _PartyScope.any,
    itemKind: 'all',
  ),
  _Def(
    'درآمد سالانه',
    'درآمد و سود',
    (r, p) => r.periodReport(
      p.range,
      Granularity.year,
      partyId: p.partyId,
      itemId: p.itemId,
    ),
    party: _PartyScope.any,
    itemKind: 'all',
  ),
  _Def(
    'سود و زیان',
    'درآمد و سود',
    (r, p) => r.profitLoss(p.range, partyId: p.partyId, itemId: p.itemId),
    party: _PartyScope.any,
    itemKind: 'all',
  ),
  _Def(
    'مجموع فروش کالا',
    'فروش',
    (r, p) => r.itemSales(
      p.range,
      products: true,
      partyId: p.partyId,
      itemId: p.itemId,
    ),
    party: _PartyScope.customer,
    itemKind: 'product',
  ),
  _Def(
    'مجموع فروش خدمات',
    'فروش',
    (r, p) => r.itemSales(
      p.range,
      products: false,
      partyId: p.partyId,
      itemId: p.itemId,
    ),
    party: _PartyScope.customer,
    itemKind: 'service',
  ),
  _Def(
    'پرفروش‌ترین کالاها',
    'فروش',
    (r, p) => r.itemSales(p.range, products: true, partyId: p.partyId, top: 10),
    party: _PartyScope.customer,
  ),
  _Def(
    'پرفروش‌ترین خدمات',
    'فروش',
    (r, p) =>
        r.itemSales(p.range, products: false, partyId: p.partyId, top: 10),
    party: _PartyScope.customer,
  ),
  _Def(
    'گزارش هزینه‌ها',
    'هزینه و پرداخت',
    (r, p) => r.expenses(p.range, partyId: p.partyId),
    party: _PartyScope.supplier,
  ),
  _Def(
    'گزارش پرداخت‌ها',
    'هزینه و پرداخت',
    (r, p) => r.payments(
      p.range,
      partyId: p.partyId,
      method: p.method,
      direction: p.direction,
    ),
    party: _PartyScope.any,
    payFilters: true,
  ),
  _Def(
    'بدهی مشتریان',
    'مانده حساب‌ها',
    (r, p) => r.receivables(kind: p.partyKind, credit: p.credit),
    usesRange: false,
    receivable: true,
  ),
  _Def(
    'فاکتورهای تسویه‌نشده',
    'مانده حساب‌ها',
    (r, p) => r.unsettled(p.range, kind: p.invKind, partyId: p.partyId),
    party: _PartyScope.any,
    unsettledKind: true,
  ),
];

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  int selected = 0;
  final p = _Params();
  ReportTable? table;
  List<Party> customers = [];
  List<Party> suppliers = [];
  List<Item> items = [];
  bool busy = false;

  _Def get def => _defs[selected];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = context.svc;
      customers = s.parties.list('customer');
      suppliers = s.parties.list('supplier');
      items = s.items.list();
      _run();
    });
  }

  void _run() {
    if (!mounted) return;
    setState(() => busy = true);
    final r = tryValue(context, () => def.build(context.svc.reports, p));
    setState(() {
      table = r;
      busy = false;
    });
  }

  void _select(int i) {
    selected = i;
    p.partyId = null;
    p.itemId = null;
    _run();
  }

  List<Party> get _partyOptions => switch (def.party) {
    _PartyScope.customer => customers,
    _PartyScope.supplier => suppliers,
    _PartyScope.any => [...customers, ...suppliers],
    _PartyScope.none => const [],
  };

  List<Item> get _itemOptions => def.itemKind == 'product'
      ? items.where((i) => i.isProduct).toList()
      : (def.itemKind == 'service'
            ? items.where((i) => !i.isProduct).toList()
            : items);

  String _fileName(String ext) {
    final t = table?.title ?? 'report';
    return '${t.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')}-${isoDate(DateTime.now())}.$ext';
  }

  Future<void> _exportPdf() async {
    final t = table;
    if (t == null) return;
    try {
      final bytes = await PdfExport.report(t);
      final path = await FileService.saveBytes(
        title: 'ذخیره PDF',
        fileName: _fileName('pdf'),
        ext: 'pdf',
        bytes: bytes,
      );
      if (path != null && mounted) toast(context, 'ذخیره شد: $path');
    } catch (e) {
      if (mounted) toast(context, 'ساخت PDF ناموفق بود: $e', error: true);
    }
  }

  Future<void> _exportExcel() async {
    final t = table;
    if (t == null) return;
    try {
      final path = await FileService.saveBytes(
        title: 'ذخیره Excel',
        fileName: _fileName('xlsx'),
        ext: 'xlsx',
        bytes: reportToXlsx(t),
      );
      if (path != null && mounted) toast(context, 'ذخیره شد: $path');
    } catch (e) {
      if (mounted) toast(context, 'ساخت Excel ناموفق بود: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          title: 'گزارش‌های مالی',
          subtitle: 'فروش، دریافتی، هزینه و سود به‌صورت جداگانه محاسبه می‌شوند',
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 230, child: _menu(context)),
              const SizedBox(width: 16),
              Expanded(child: _content(context)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _menu(BuildContext context) {
    final children = <Widget>[];
    String? lastGroup;
    for (var i = 0; i < _defs.length; i++) {
      final d = _defs[i];
      if (d.group != lastGroup) {
        lastGroup = d.group;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text(
              d.group,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.muted(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }
      children.add(
        ListTile(
          dense: true,
          selected: i == selected,
          title: Text(d.title),
          onTap: () => _select(i),
        ),
      );
    }
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView(children: children),
    );
  }

  Widget _content(BuildContext context) {
    final d = def;
    final t = table;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      d.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: t == null ? null : _exportPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('PDF'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: t == null ? null : _exportExcel,
                    icon: const Icon(Icons.table_chart_outlined),
                    label: const Text('Excel'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (d.usesRange)
                    DateRangeBar(
                      range: p.range,
                      onChanged: (r) {
                        p.range = r;
                        _run();
                      },
                    ),
                  if (d.party != _PartyScope.none)
                    SizedBox(
                      width: 220,
                      child: DropdownField<int?>(
                        label: 'طرف‌حساب',
                        value: _partyOptions.any((x) => x.id == p.partyId)
                            ? p.partyId
                            : null,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('همه'),
                          ),
                          for (final x in _partyOptions)
                            DropdownMenuItem<int?>(
                              value: x.id,
                              child: Text(
                                x.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) {
                          p.partyId = v;
                          _run();
                        },
                      ),
                    ),
                  if (d.itemKind.isNotEmpty)
                    SizedBox(
                      width: 220,
                      child: DropdownField<int?>(
                        label: 'کالا / خدمت',
                        value: _itemOptions.any((x) => x.id == p.itemId)
                            ? p.itemId
                            : null,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('همه'),
                          ),
                          for (final x in _itemOptions)
                            DropdownMenuItem<int?>(
                              value: x.id,
                              child: Text(
                                x.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) {
                          p.itemId = v;
                          _run();
                        },
                      ),
                    ),
                  if (d.payFilters) ...[
                    SizedBox(
                      width: 160,
                      child: DropdownField<String>(
                        label: 'روش',
                        value: p.method,
                        items: [
                          const DropdownMenuItem(value: '', child: Text('همه')),
                          for (final e in kMethodLabels.entries)
                            DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                        ],
                        onChanged: (v) {
                          p.method = v ?? '';
                          _run();
                        },
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: DropdownField<String>(
                        label: 'جهت',
                        value: p.direction,
                        items: const [
                          DropdownMenuItem(value: '', child: Text('همه')),
                          DropdownMenuItem(value: 'in', child: Text('دریافت')),
                          DropdownMenuItem(value: 'out', child: Text('پرداخت')),
                        ],
                        onChanged: (v) {
                          p.direction = v ?? '';
                          _run();
                        },
                      ),
                    ),
                  ],
                  if (d.unsettledKind)
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'sale', label: Text('فروش')),
                        ButtonSegment(value: 'purchase', label: Text('خرید')),
                      ],
                      selected: {p.invKind},
                      onSelectionChanged: (s) {
                        p.invKind = s.first;
                        p.partyId = null;
                        _run();
                      },
                    ),
                  if (d.receivable) ...[
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'customer',
                          label: Text('مشتریان'),
                        ),
                        ButtonSegment(
                          value: 'supplier',
                          label: Text('تأمین‌کنندگان'),
                        ),
                      ],
                      selected: {p.partyKind},
                      onSelectionChanged: (s) {
                        p.partyKind = s.first;
                        _run();
                      },
                    ),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('بدهکاران')),
                        ButtonSegment(value: true, label: Text('بستانکاران')),
                      ],
                      selected: {p.credit},
                      onSelectionChanged: (s) {
                        p.credit = s.first;
                        _run();
                      },
                    ),
                  ],
                ],
              ),
              if (t != null && t.subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    t.subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.muted(context),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (t?.chart != null && !t!.chart!.isEmpty) ...[
          AppCard(child: BarChartView(data: t.chart!, height: 190)),
          const SizedBox(height: 12),
        ],
        Expanded(
          child: busy || t == null
              ? const Center(child: CircularProgressIndicator())
              : ReportGrid(table: t),
        ),
      ],
    );
  }
}
