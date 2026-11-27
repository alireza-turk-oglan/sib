import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/utils/jalali.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/jalali_picker.dart';
import '../../core/widgets/search_picker.dart';
import '../../data/models.dart';
import '../../domain/invoice_calc.dart';
import '../customers/party_form.dart';

/// باز کردن ویرایشگر فاکتور (جدید یا ویرایش). true = ذخیره شد.
Future<bool> openInvoiceEditor(
  BuildContext context, {
  required String kind,
  int? invoiceId,
}) async {
  final r = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => InvoiceEditorPage(kind: kind, invoiceId: invoiceId),
    ),
  );
  return r ?? false;
}

class _Line {
  int? itemId;
  String itemKind; // product | service | free
  double? stock;
  final TextEditingController title;
  final TextEditingController qty;
  final TextEditingController price;
  final TextEditingController discount;
  _Line({
    this.itemId,
    required this.itemKind,
    String title = '',
    String qty = '1',
    String price = '',
    String discount = '',
  }) : title = TextEditingController(text: title),
       qty = TextEditingController(text: qty),
       price = TextEditingController(text: price),
       discount = TextEditingController(text: discount);

  void dispose() {
    title.dispose();
    qty.dispose();
    price.dispose();
    discount.dispose();
  }

  double get qtyValue => parseQty(qty.text) ?? 0;
  int get priceValue => parseMoney(price.text) ?? 0;
  int get discountValue => parseMoney(discount.text) ?? 0;
  int get total {
    final t = lineTotal(qtyValue, priceValue, discountValue);
    return t < 0 ? 0 : t;
  }
}

class InvoiceEditorPage extends StatefulWidget {
  final String kind;
  final int? invoiceId;
  const InvoiceEditorPage({super.key, required this.kind, this.invoiceId});

  @override
  State<InvoiceEditorPage> createState() => _InvoiceEditorPageState();
}

class _InvoiceEditorPageState extends State<InvoiceEditorPage> {
  final _form = GlobalKey<FormState>();
  final _lines = <_Line>[];
  final _desc = TextEditingController();
  final _partyName = TextEditingController();
  final _payNow = TextEditingController();
  String _payMethod = 'cash';
  DateTime _date = DateTime.now();
  Party? _party;
  int _number = 0;
  int _paid = 0;
  bool _loaded = false;

  bool get _isSale => widget.kind == 'sale';
  bool get _isEdit => widget.invoiceId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  void _init() {
    if (!mounted) return;
    final s = context.svc;
    if (_isEdit) {
      final d = tryValue(context, () => s.invoices.get(widget.invoiceId!));
      if (d == null) {
        if (mounted) Navigator.pop(context, false);
        return;
      }
      _number = d.summary.number;
      _paid = d.summary.paid;
      _date = parseIso(d.summary.date) ?? DateTime.now();
      _desc.text = d.summary.description ?? '';
      if (d.summary.partyId != null) {
        _party = s.parties.get(d.summary.partyId!);
      } else {
        _partyName.text = d.summary.partyName;
      }
      for (final l in d.lines) {
        _lines.add(
          _Line(
            itemId: l.itemId,
            itemKind: l.itemKind,
            title: l.title,
            qty: fmtQtyInput(l.qty),
            price: groupThousands(l.unitPrice),
            discount: l.discount == 0 ? '' : groupThousands(l.discount),
          ),
        );
      }
    } else {
      _number = s.invoices.nextNumber(widget.kind);
      _lines.add(_Line(itemKind: 'free'));
    }
    setState(() => _loaded = true);
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    _desc.dispose();
    _partyName.dispose();
    _payNow.dispose();
    super.dispose();
  }

  int get _total => _lines.fold(0, (s, l) => s + l.total);

  Future<void> _pickParty() async {
    final s = context.svc;
    final kind = _isSale ? 'customer' : 'supplier';
    final list = s.parties.list(kind).where((p) => p.isActive).toList();
    final picked = await showSearchPicker<Party>(
      context,
      title: _isSale ? 'انتخاب مشتری' : 'انتخاب تأمین‌کننده',
      items: list,
      label: (p) => p.name,
      subtitle: (p) => '${p.code}${p.mobile != null ? ' • ${p.mobile}' : ''}',
      createLabel: _isSale ? 'مشتری جدید' : 'تأمین‌کننده جدید',
      onCreate: () async {
        final id = await showPartyForm(context, kind: kind);
        return id == null ? null : s.parties.get(id);
      },
    );
    if (picked != null) setState(() => _party = picked);
  }

  Future<void> _pickItem(_Line line) async {
    final s = context.svc;
    final items = s.items.list(includeInactive: false);
    final picked = await showSearchPicker<Item>(
      context,
      title: 'انتخاب کالا یا خدمت',
      items: items,
      label: (i) => i.name,
      subtitle: (i) =>
          '${i.code} • ${i.isProduct ? 'کالا' : 'خدمت'} • ${fmtToman(_isSale ? i.salePrice : i.purchasePrice)}',
      trailing: (i) => i.isProduct && i.trackStock
          ? Text(
              'موجودی ${fmtQty(i.stock)}',
              style: TextStyle(
                fontSize: 12,
                color: i.lowStock ? AppColors.negative(context) : null,
              ),
            )
          : const SizedBox.shrink(),
    );
    if (picked == null) return;
    setState(() {
      line.itemId = picked.id;
      line.itemKind = picked.kind;
      line.stock = picked.isProduct && picked.trackStock ? picked.stock : null;
      line.title.text = picked.name;
      line.price.text = groupThousands(
        _isSale ? picked.salePrice : picked.purchasePrice,
      );
      if (parseQty(line.qty.text) == null || line.qtyValue <= 0) {
        line.qty.text = '1';
      }
    });
  }

  void _addItemLine() {
    final l = _Line(itemKind: 'free');
    setState(() => _lines.add(l));
    _pickItem(l).then((_) {
      // اگر کاربر انصراف داد، ردیف خالیِ بی‌استفاده حذف شود
      if (mounted &&
          l.itemId == null &&
          l.title.text.isEmpty &&
          l.price.text.isEmpty &&
          _lines.length > 1) {
        setState(() {
          _lines.remove(l);
          l.dispose();
        });
      }
    });
  }

  void _removeLine(_Line l) {
    if (_lines.length == 1) {
      toast(context, 'فاکتور باید حداقل یک ردیف داشته باشد.', error: true);
      return;
    }
    setState(() {
      _lines.remove(l);
      l.dispose();
    });
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final s = context.svc;
    final lines = <LineInput>[];
    for (var i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      final err = validateLine(
        title: l.title.text,
        qty: l.qtyValue,
        unitPrice: l.priceValue,
        discount: l.discountValue,
      );
      if (err != null) {
        toast(context, 'ردیف ${faDigits(i + 1)}: $err', error: true);
        return;
      }
      lines.add(
        LineInput(
          itemId: l.itemId,
          title: l.title.text,
          qty: l.qtyValue,
          unitPrice: l.priceValue,
          discount: l.discountValue,
        ),
      );
    }
    final payNow = _isEdit ? 0 : (parseMoney(_payNow.text) ?? 0);
    if (payNow > _total) {
      toast(context, 'مبلغ پرداخت‌شده از جمع فاکتور بیشتر است.', error: true);
      return;
    }
    final draft = InvoiceDraft(
      id: widget.invoiceId,
      kind: widget.kind,
      partyId: _party?.id,
      partyName: _party == null ? _partyName.text : null,
      date: isoDate(_date),
      description: _desc.text,
      lines: lines,
    );
    final id = tryValue<int>(context, () => s.invoices.save(draft));
    if (id == null) return;
    if (payNow > 0) {
      tryRun(
        context,
        () => s.payments.add(
          invoiceId: id,
          method: _payMethod,
          amount: payNow,
          date: isoDate(_date),
          description: '',
        ),
      );
    }
    toast(context, _isEdit ? 'فاکتور ویرایش شد.' : 'فاکتور ثبت شد.');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final title =
        '${_isEdit ? 'ویرایش' : 'ثبت'} ${_isSale ? 'فاکتور فروش و خدمات' : 'فاکتور خرید و هزینه‌ها'}';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                'شماره ${faDigits(_number)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        AppCard(child: _header(context)),
                        const SizedBox(height: 14),
                        AppCard(child: _linesCard(context)),
                        const SizedBox(height: 14),
                        AppCard(child: _totals(context)),
                      ],
                    ),
                  ),
                  _bottomBar(context),
                ],
              ),
            ),
    );
  }

  Widget _header(BuildContext context) => Wrap(
    spacing: 14,
    runSpacing: 14,
    crossAxisAlignment: WrapCrossAlignment.start,
    children: [
      SizedBox(
        width: 200,
        child: JalaliDateField(
          label: 'تاریخ',
          value: _date,
          onChanged: (d) => setState(() => _date = d ?? _date),
        ),
      ),
      SizedBox(
        width: 300,
        child: _party != null
            ? InkWell(
                onTap: _pickParty,
                child: InputDecorator(
                  decoration: deco(
                    _isSale ? 'مشتری' : 'تأمین‌کننده',
                    suffix: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'حذف انتخاب',
                      onPressed: _paid > 0
                          ? null
                          : () => setState(() => _party = null),
                    ),
                  ),
                  child: Text(_party!.name),
                ),
              )
            : Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _partyName,
                      maxLength: 100,
                      decoration: deco(
                        _isSale
                            ? 'مشتری متفرقه (اختیاری)'
                            : 'طرف‌حساب (اختیاری)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'انتخاب از فهرست',
                    child: IconButton.filledTonal(
                      onPressed: _pickParty,
                      icon: const Icon(Icons.person_search),
                    ),
                  ),
                ],
              ),
      ),
      SizedBox(
        width: 360,
        child: TextFormField(
          controller: _desc,
          maxLength: 500,
          decoration: deco('توضیحات'),
        ),
      ),
    ],
  );

  Widget _linesCard(BuildContext context) {
    final muted = AppColors.muted(context);
    Widget h(String t, double? w) => w == null
        ? Expanded(
            child: Text(t, style: TextStyle(fontSize: 12, color: muted)),
          )
        : SizedBox(
            width: w,
            child: Text(t, style: TextStyle(fontSize: 12, color: muted)),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            h('کالا / خدمت / شرح', null),
            const SizedBox(width: 8),
            h('تعداد', 90),
            const SizedBox(width: 8),
            h('قیمت واحد', 140),
            const SizedBox(width: 8),
            h('تخفیف', 110),
            const SizedBox(width: 8),
            h('جمع ردیف', 120),
            const SizedBox(width: 40),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _lines.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _lineRow(context, _lines[i], i),
          ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: _addItemLine,
              icon: const Icon(Icons.add),
              label: const Text('افزودن کالا / خدمت'),
            ),
            TextButton.icon(
              onPressed: () =>
                  setState(() => _lines.add(_Line(itemKind: 'free'))),
              icon: const Icon(Icons.edit_note),
              label: Text(
                _isSale ? 'ردیف آزاد (خدمت متفرقه)' : 'ردیف آزاد (هزینه)',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _lineRow(BuildContext context, _Line l, int index) {
    final isFree = l.itemId == null;
    final over = _isSale && l.stock != null && l.qtyValue > l.stock!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: isFree
              ? TextFormField(
                  controller: l.title,
                  decoration: deco(_isSale ? 'شرح خدمت' : 'شرح هزینه'),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => requiredValidator(v, 'شرح را وارد کنید.'),
                )
              : InkWell(
                  onTap: () => _pickItem(l),
                  child: InputDecorator(
                    decoration: deco(
                      l.itemKind == 'product' ? 'کالا' : 'خدمت',
                      suffix: const Icon(Icons.arrow_drop_down),
                    ),
                    child: Text(
                      l.title.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              QtyField(
                controller: l.qty,
                label: 'تعداد',
                onChanged: (_) => setState(() {}),
              ),
              if (l.stock != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'موجودی ${fmtQty(l.stock!)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: over
                          ? AppColors.negative(context)
                          : AppColors.muted(context),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 140,
          child: MoneyField(
            controller: l.price,
            label: 'قیمت واحد',
            suffixText: '',
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
          child: MoneyField(
            controller: l.discount,
            label: 'تخفیف',
            required: false,
            suffixText: '',
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              fmtMoney(l.total),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: IconButton(
            onPressed: () => _removeLine(l),
            icon: const Icon(Icons.delete_outline),
            tooltip: 'حذف ردیف',
          ),
        ),
      ],
    );
  }

  Widget _totals(BuildContext context) {
    final total = _total;
    return Wrap(
      spacing: 24,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'جمع کل فاکتور',
              style: TextStyle(color: AppColors.muted(context)),
            ),
            Text(
              fmtToman(total),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        if (_isEdit) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'پرداخت‌شده',
                style: TextStyle(color: AppColors.muted(context)),
              ),
              Text(
                fmtToman(_paid),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.positive(context),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'باقی‌مانده',
                style: TextStyle(color: AppColors.muted(context)),
              ),
              Text(
                fmtToman(total - _paid),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: total - _paid < 0 ? AppColors.negative(context) : null,
                ),
              ),
            ],
          ),
          if (total < _paid)
            Text(
              'جمع فاکتور نباید کمتر از پرداخت‌ها باشد.',
              style: TextStyle(color: AppColors.negative(context)),
            ),
        ] else ...[
          SizedBox(
            width: 220,
            child: MoneyField(
              controller: _payNow,
              label: _isSale ? 'دریافتی همین‌ لحظه' : 'پرداختی همین لحظه',
              required: false,
            ),
          ),
          SizedBox(
            width: 160,
            child: DropdownField<String>(
              label: 'روش',
              value: _payMethod,
              items: [
                for (final e in kMethodLabels.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _payMethod = v ?? 'cash'),
            ),
          ),
          TextButton(
            onPressed: total > 0
                ? () => setState(() => _payNow.text = groupThousands(total))
                : null,
            child: const Text('تسویه کامل'),
          ),
        ],
      ],
    );
  }

  Widget _bottomBar(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.card(context),
      border: Border(top: BorderSide(color: AppColors.line(context))),
    ),
    child: Row(
      children: [
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.check),
          label: const Text('ذخیره فاکتور'),
        ),
        const SizedBox(width: 10),
        OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('انصراف'),
        ),
        const Spacer(),
        Text(
          'ردیف‌ها: ${faDigits(_lines.length)}',
          style: TextStyle(color: AppColors.muted(context)),
        ),
      ],
    ),
  );
}

/// مقدار برای نمایش در فیلد ورودی: ۲٫۵ ← 2.5 (لاتین، چون ورودی با ارقام لاتین پارس می‌شود)
String fmtQtyInput(double q) {
  var s = q.toStringAsFixed(3);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}
