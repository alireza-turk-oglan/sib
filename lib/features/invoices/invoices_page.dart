import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/utils/jalali.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/jalali_picker.dart';
import '../../data/models.dart';
import '../../domain/invoice_calc.dart';
import '../payments/payment_dialog.dart';
import 'invoice_editor_page.dart';
import 'invoice_view.dart';

class InvoicesPage extends StatefulWidget {
  final String initialKind;
  const InvoicesPage({super.key, this.initialKind = 'sale'});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  late String kind = widget.initialKind;
  DateRange range = DateRange.thisJalaliYear();
  int? partyId;
  String status = 'all';
  final _number = TextEditingController();
  List<InvoiceSummary> list = [];
  List<Party> parties = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reload(reloadParties: true),
    );
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  void _reload({bool reloadParties = false}) {
    if (!mounted) return;
    final s = context.svc;
    if (reloadParties) {
      parties = s.parties.list(kind == 'sale' ? 'customer' : 'supplier');
    }
    final n = int.tryParse(enDigits(_number.text.trim()));
    final r = tryValue(
      context,
      () => s.invoices.list(
        kind: kind,
        from: range.fromIso,
        to: range.toIso,
        partyId: partyId,
        number: n,
        status: status,
        limit: 500,
      ),
    );
    setState(() {
      list = r ?? [];
      loading = false;
    });
  }

  Future<void> _new() async {
    if (await openInvoiceEditor(context, kind: kind)) {
      _reload(reloadParties: true);
    }
  }

  Future<void> _open(InvoiceSummary i) async {
    if (await showInvoiceView(context, i.id)) _reload(reloadParties: true);
  }

  Future<void> _pay(InvoiceSummary i) async {
    final ok = await showPaymentDialog(
      context,
      invoiceId: i.id,
      partyId: i.partyId,
      partyName: i.partyName,
      incoming: i.isSale,
      remaining: i.remaining,
      invoiceLabel:
          'فاکتور شماره ${faDigits(i.number)} — مانده: ${fmtToman(i.remaining)}',
    );
    if (ok) _reload();
  }

  Future<void> _delete(InvoiceSummary i) async {
    if (!await confirmDialog(
      context,
      title: 'حذف فاکتور',
      message: 'فاکتور شماره ${faDigits(i.number)} حذف شود؟',
      confirmLabel: 'حذف',
      danger: true,
    )) {
      return;
    }
    if (!mounted) return;
    if (tryRun(context, () => context.svc.invoices.delete(i.id))) {
      toast(context, 'فاکتور حذف شد.');
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSum = list.fold<int>(0, (a, b) => a + b.total);
    final paidSum = list.fold<int>(0, (a, b) => a + b.paid);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'فاکتورها',
            subtitle: 'فروش و خدمات، خرید و هزینه‌ها',
            actions: [
              FilledButton.icon(
                onPressed: _new,
                icon: const Icon(Icons.add),
                label: Text(
                  kind == 'sale'
                      ? 'فاکتور فروش جدید'
                      : 'فاکتور خرید / هزینه جدید',
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'sale', label: Text('فروش و خدمات')),
                  ButtonSegment(
                    value: 'purchase',
                    label: Text('خرید و هزینه‌ها'),
                  ),
                ],
                selected: {kind},
                onSelectionChanged: (s) {
                  kind = s.first;
                  partyId = null;
                  _reload(reloadParties: true);
                },
              ),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _number,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  decoration: deco('شماره فاکتور'),
                  onSubmitted: (_) => _reload(),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownField<int?>(
                  label: kind == 'sale' ? 'مشتری' : 'تأمین‌کننده',
                  value: partyId,
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('همه'),
                    ),
                    for (final p in parties)
                      DropdownMenuItem<int?>(
                        value: p.id,
                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) {
                    partyId = v;
                    _reload();
                  },
                ),
              ),
              SizedBox(
                width: 170,
                child: DropdownField<String>(
                  label: 'وضعیت پرداخت',
                  value: status,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('همه')),
                    DropdownMenuItem(value: 'open', child: Text('تسویه‌نشده')),
                    DropdownMenuItem(
                      value: 'unpaid',
                      child: Text('پرداخت‌نشده'),
                    ),
                    DropdownMenuItem(
                      value: 'partial',
                      child: Text('پرداخت جزئی'),
                    ),
                    DropdownMenuItem(value: 'paid', child: Text('تسویه‌شده')),
                  ],
                  onChanged: (v) {
                    status = v ?? 'all';
                    _reload();
                  },
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => _reload(),
                icon: const Icon(Icons.search),
                tooltip: 'جست‌وجو',
              ),
            ],
          ),
          const SizedBox(height: 10),
          DateRangeBar(
            range: range,
            onChanged: (r) {
              range = r;
              _reload();
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : _table(context),
          ),
          const SizedBox(height: 8),
          Text(
            '${faDigits(list.length)} فاکتور • جمع: ${fmtToman(totalSum)} • پرداخت‌شده: ${fmtToman(paidSum)} • باقی‌مانده: ${fmtToman(totalSum - paidSum)}${list.length >= 500 ? ' (۵۰۰ مورد آخر؛ بازه را محدودتر کنید)' : ''}',
            style: TextStyle(color: AppColors.muted(context)),
          ),
        ],
      ),
    );
  }

  Widget _table(BuildContext context) {
    if (list.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        text: 'فاکتوری برای این فیلتر پیدا نشد.',
      );
    }
    final head = TextStyle(fontSize: 12, color: AppColors.muted(context));
    Widget c(String t, {double? w, TextStyle? st, bool end = false}) {
      final x = Align(
        alignment: end
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Text(t, style: st, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
      return w == null ? Expanded(child: x) : SizedBox(width: w, child: x);
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                c('شماره', w: 60, st: head),
                c('تاریخ', w: 90, st: head),
                c('طرف‌حساب', st: head),
                c('مبلغ', w: 110, st: head, end: true),
                c('پرداخت‌شده', w: 110, st: head, end: true),
                c('مانده', w: 110, st: head, end: true),
                c('وضعیت', w: 110, st: head),
                const SizedBox(width: 130),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final i = list[idx];
                return InkWell(
                  onTap: () => _open(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    child: SizedBox(
                      height: 38,
                      child: Row(
                        children: [
                          c(
                            faDigits(i.number),
                            w: 60,
                            st: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          c(fmtJalali(i.date), w: 90),
                          c(i.partyName.isEmpty ? 'متفرقه' : i.partyName),
                          c(fmtMoney(i.total), w: 110, end: true),
                          c(fmtMoney(i.paid), w: 110, end: true),
                          c(
                            fmtMoney(i.remaining),
                            w: 110,
                            end: true,
                            st: TextStyle(
                              color: i.remaining > 0
                                  ? AppColors.negative(context)
                                  : null,
                            ),
                          ),
                          SizedBox(
                            width: 110,
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: StatusChip(
                                payStatusLabel(i.status),
                                statusColor(context, i.status),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 130,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (i.remaining > 0)
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: i.isSale
                                        ? 'ثبت دریافت'
                                        : 'ثبت پرداخت',
                                    onPressed: () => _pay(i),
                                    icon: const Icon(
                                      Icons.payments_outlined,
                                      size: 20,
                                    ),
                                  ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'ویرایش',
                                  onPressed: () async {
                                    if (await openInvoiceEditor(
                                      context,
                                      kind: i.kind,
                                      invoiceId: i.id,
                                    )) {
                                      _reload();
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 20,
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'حذف',
                                  onPressed: () => _delete(i),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
