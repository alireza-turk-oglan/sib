import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/utils/jalali.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/jalali_picker.dart';
import '../../data/models.dart';

/// فرم کالا/خدمت. true = ذخیره شد.
Future<bool> showItemForm(
  BuildContext context, {
  required String kind,
  Item? edit,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => _ItemForm(kind: kind, edit: edit),
  );
  return r ?? false;
}

class _ItemForm extends StatefulWidget {
  final String kind;
  final Item? edit;
  const _ItemForm({required this.kind, this.edit});

  @override
  State<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<_ItemForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.edit?.name ?? '');
  final _code = TextEditingController();
  late final _sale = TextEditingController(
    text: widget.edit == null ? '' : groupThousands(widget.edit!.salePrice),
  );
  late final _buy = TextEditingController(
    text: widget.edit == null || widget.edit!.purchasePrice == 0
        ? ''
        : groupThousands(widget.edit!.purchasePrice),
  );
  final _opening = TextEditingController();
  late final _min = TextEditingController(
    text: widget.edit == null || widget.edit!.minStockMilli == 0
        ? ''
        : fmtQtyPlain(widget.edit!.minStockMilli / 1000),
  );
  late final _desc = TextEditingController(
    text: widget.edit?.description ?? '',
  );
  late bool _track = widget.edit?.trackStock ?? true;
  late bool _active = widget.edit?.isActive ?? true;
  int? _categoryId;
  List<Category> _cats = [];

  bool get _isProduct => widget.kind == 'product';

  @override
  void initState() {
    super.initState();
    _categoryId = widget.edit?.categoryId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _cats = context.svc.items.categories(widget.kind));
      }
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _code, _sale, _buy, _opening, _min, _desc]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final repo = context.svc.items;
    final sale = parseMoney(_sale.text) ?? 0;
    final buy = parseMoney(_buy.text) ?? 0;
    final opening = ((parseQty(_opening.text) ?? 0) * 1000).round();
    final min = ((parseQty(_min.text) ?? 0) * 1000).round();
    final ok = tryRun(context, () {
      if (widget.edit == null) {
        repo.create(
          kind: widget.kind,
          name: _name.text,
          code: _code.text,
          categoryId: _categoryId,
          description: _desc.text,
          salePrice: sale,
          purchasePrice: buy,
          trackStock: _track,
          openingStockMilli: opening,
          minStockMilli: min,
          date: isoDate(DateTime.now()),
        );
      } else {
        repo.update(
          widget.edit!.id,
          name: _name.text,
          categoryId: _categoryId,
          description: _desc.text,
          salePrice: sale,
          purchasePrice: buy,
          trackStock: _track,
          minStockMilli: min,
          isActive: _active,
        );
      }
    });
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final noun = _isProduct ? 'کالا' : 'خدمت';
    return AppDialog(
      title: widget.edit == null ? 'افزودن $noun' : 'ویرایش $noun',
      width: 520,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('انصراف'),
        ),
        FilledButton(onPressed: _save, child: const Text('ذخیره')),
      ],
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              maxLength: 120,
              decoration: deco('نام $noun'),
              validator: (v) => requiredValidator(v, 'نام را وارد کنید.'),
            ),
            const SizedBox(height: 6),
            if (widget.edit == null)
              TextFormField(
                controller: _code,
                textDirection: TextDirection.ltr,
                decoration: deco('کد (خالی = خودکار)'),
              )
            else
              Text('کد: ${widget.edit!.code}'),
            const SizedBox(height: 12),
            DropdownField<int?>(
              label: 'دسته‌بندی',
              value: _cats.any((c) => c.id == _categoryId) ? _categoryId : null,
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('— بدون دسته —'),
                ),
                for (final c in _cats)
                  DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: MoneyField(controller: _sale, label: 'قیمت فروش'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MoneyField(
                    controller: _buy,
                    label: 'قیمت خرید (اختیاری)',
                    required: false,
                  ),
                ),
              ],
            ),
            if (_isProduct) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('مدیریت موجودی انبار'),
                value: _track,
                onChanged: (v) => setState(() => _track = v),
              ),
              if (_track)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.edit == null)
                      Expanded(
                        child: QtyField(
                          controller: _opening,
                          label: 'موجودی اولیه',
                          required: false,
                        ),
                      ),
                    if (widget.edit == null) const SizedBox(width: 10),
                    Expanded(
                      child: QtyField(
                        controller: _min,
                        label: 'حداقل موجودی (هشدار)',
                        required: false,
                      ),
                    ),
                  ],
                ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _desc,
              maxLines: 2,
              maxLength: 500,
              decoration: deco('توضیحات'),
            ),
            if (widget.edit != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('فعال'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
          ],
        ),
      ),
    );
  }
}

String fmtQtyPlain(double q) {
  var s = q.toStringAsFixed(3);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

/// مدیریت دسته‌بندی‌ها
Future<void> showCategoriesDialog(BuildContext context, String kind) =>
    showDialog<void>(
      context: context,
      builder: (_) => _Categories(kind: kind),
    );

class _Categories extends StatefulWidget {
  final String kind;
  const _Categories({required this.kind});

  @override
  State<_Categories> createState() => _CategoriesState();
}

class _CategoriesState extends State<_Categories> {
  final _name = TextEditingController();
  List<Category> cats = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _load() {
    if (mounted) {
      setState(() => cats = context.svc.items.categories(widget.kind));
    }
  }

  void _add() {
    if (_name.text.trim().isEmpty) return;
    if (tryRun(
      context,
      () => context.svc.items.addCategory(widget.kind, _name.text),
    )) {
      _name.clear();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: 'دسته‌بندی ${widget.kind == 'product' ? 'کالاها' : 'خدمات'}',
    width: 420,
    actions: [
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('بستن'),
      ),
    ],
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _name,
                decoration: deco('دسته‌بندی جدید'),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: _add, icon: const Icon(Icons.add)),
          ],
        ),
        const SizedBox(height: 10),
        if (cats.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('دسته‌بندی‌ای تعریف نشده است.'),
          ),
        for (final c in cats)
          ListTile(
            dense: true,
            title: Text(c.name),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                if (tryRun(
                  context,
                  () => context.svc.items.deleteCategory(c.id),
                )) {
                  _load();
                }
              },
            ),
          ),
      ],
    ),
  );
}

/// تعدیل دستی موجودی. true = ثبت شد.
Future<bool> showStockAdjust(BuildContext context, Item item) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => _StockAdjust(item: item),
  );
  return r ?? false;
}

class _StockAdjust extends StatefulWidget {
  final Item item;
  const _StockAdjust({required this.item});

  @override
  State<_StockAdjust> createState() => _StockAdjustState();
}

class _StockAdjustState extends State<_StockAdjust> {
  final _form = GlobalKey<FormState>();
  final _qty = TextEditingController();
  final _note = TextEditingController();
  bool _increase = true;
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final milli = ((parseQty(_qty.text) ?? 0) * 1000).round();
    final svc = context.svc;
    final ok = tryRun(
      context,
      () => svc.items.adjustStock(
        widget.item.id,
        _increase ? milli : -milli,
        date: isoDate(_date),
        note: _note.text,
        allowNegative: svc.settings.allowNegativeStock,
      ),
    );
    if (ok) {
      toast(context, 'موجودی تعدیل شد.');
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: 'تعدیل موجودی: ${widget.item.name}',
    width: 420,
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('انصراف'),
      ),
      FilledButton(onPressed: _save, child: const Text('ثبت')),
    ],
    child: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('موجودی فعلی: ${fmtQty(widget.item.stock)}'),
          const SizedBox(height: 10),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('افزایش')),
              ButtonSegment(value: false, label: Text('کاهش')),
            ],
            selected: {_increase},
            onSelectionChanged: (s) => setState(() => _increase = s.first),
          ),
          const SizedBox(height: 12),
          QtyField(controller: _qty, label: 'مقدار'),
          const SizedBox(height: 12),
          JalaliDateField(
            label: 'تاریخ',
            value: _date,
            onChanged: (d) => setState(() => _date = d ?? _date),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _note,
            maxLength: 200,
            decoration: deco('علت (اختیاری، مثلاً انبارگردانی)'),
          ),
        ],
      ),
    ),
  );
}

/// تاریخچه تغییر قیمت و موجودی
Future<void> showItemHistory(BuildContext context, Item item) =>
    showDialog<void>(
      context: context,
      builder: (_) => _ItemHistory(item: item),
    );

class _ItemHistory extends StatelessWidget {
  final Item item;
  const _ItemHistory({required this.item});

  @override
  Widget build(BuildContext context) {
    final repo = context.svc.items;
    final prices = repo.priceHistory(item.id);
    final stock = item.isProduct
        ? repo.stockHistory(item.id)
        : const <Map<String, Object?>>[];
    const reasons = {
      'opening': 'موجودی اولیه',
      'sale': 'فروش',
      'purchase': 'خرید',
      'adjust': 'تعدیل',
    };
    final tabs = [
      const Tab(text: 'تغییرات قیمت'),
      if (item.isProduct) const Tab(text: 'گردش موجودی'),
    ];
    return AppDialog(
      title: 'تاریخچه: ${item.name}',
      width: 640,
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('بستن'),
        ),
      ],
      child: SizedBox(
        height: 380,
        child: DefaultTabController(
          length: tabs.length,
          child: Column(
            children: [
              TabBar(tabs: tabs),
              Expanded(
                child: TabBarView(
                  children: [
                    ListView(
                      children: [
                        for (final p in prices)
                          ListTile(
                            dense: true,
                            title: Text(
                              'فروش: ${fmtToman(p['sale_price'] as int)}   |   خرید: ${fmtToman(p['purchase_price'] as int)}',
                            ),
                            subtitle: Text(
                              '${fmtJalaliDateTime('${p['changed_at']}')} • ${p['source'] == 'purchase_invoice' ? 'فاکتور خرید' : 'دستی'}',
                            ),
                          ),
                      ],
                    ),
                    if (item.isProduct)
                      ListView(
                        children: [
                          for (final m in stock)
                            ListTile(
                              dense: true,
                              title: Text(
                                '${reasons[m['reason']] ?? m['reason']}: ${(m['qty_milli'] as int) > 0 ? '+' : ''}${fmtQty((m['qty_milli'] as int) / 1000)}',
                              ),
                              subtitle: Text(
                                '${fmtJalali('${m['date']}')}${m['inv_number'] != null ? ' • فاکتور ${faDigits(m['inv_number'])}' : ''}${m['note'] != null ? ' • ${m['note']}' : ''}',
                              ),
                            ),
                          if (stock.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'گردشی ثبت نشده است.',
                                style: TextStyle(
                                  color: AppColors.muted(context),
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
