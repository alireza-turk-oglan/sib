import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../domain/invoice_calc.dart';
import '../../services/file_service.dart';
import '../../services/pdf_export.dart';
import '../payments/payment_dialog.dart';
import 'invoice_editor_page.dart';

/// نمایش جزئیات فاکتور با امکان پرداخت، ویرایش، PDF/چاپ و حذف. true = داده تغییر کرد.
Future<bool> showInvoiceView(BuildContext context, int invoiceId) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => _InvoiceView(invoiceId: invoiceId),
  );
  return r ?? false;
}

Color statusColor(BuildContext c, PayStatus s) => switch (s) {
  PayStatus.paid => AppColors.positive(c),
  PayStatus.partial => AppColors.warning(c),
  PayStatus.unpaid => AppColors.negative(c),
};

class _InvoiceView extends StatefulWidget {
  final int invoiceId;
  const _InvoiceView({required this.invoiceId});

  @override
  State<_InvoiceView> createState() => _InvoiceViewState();
}

class _InvoiceViewState extends State<_InvoiceView> {
  InvoiceDetail? d;
  bool changed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    if (!mounted) return;
    final r = tryValue(
      context,
      () => context.svc.invoices.get(widget.invoiceId),
    );
    if (r == null) {
      Navigator.pop(context, changed);
      return;
    }
    setState(() => d = r);
  }

  Future<void> _addPayment() async {
    final x = d!;
    final s = x.summary;
    final ok = await showPaymentDialog(
      context,
      invoiceId: s.id,
      partyId: s.partyId,
      partyName: s.partyName,
      incoming: s.isSale,
      remaining: s.remaining,
      invoiceLabel:
          'فاکتور شماره ${faDigits(s.number)} — مانده: ${fmtToman(s.remaining)}',
    );
    if (ok) {
      changed = true;
      _load();
    }
  }

  Future<void> _deletePayment(PaymentRow p) async {
    if (!await confirmDialog(
      context,
      title: 'حذف پرداخت',
      message:
          'پرداخت ${fmtToman(p.amount)} مورخ ${fmtJalali(p.date)} حذف شود؟',
      confirmLabel: 'حذف',
      danger: true,
    )) {
      return;
    }
    if (!mounted) return;
    if (tryRun(context, () => context.svc.payments.delete(p.id))) {
      changed = true;
      _load();
    }
  }

  Future<void> _edit() async {
    final s = d!.summary;
    final saved = await openInvoiceEditor(
      context,
      kind: s.kind,
      invoiceId: s.id,
    );
    if (saved) {
      changed = true;
      _load();
    }
  }

  Future<void> _delete() async {
    final s = d!.summary;
    if (!await confirmDialog(
      context,
      title: 'حذف فاکتور',
      message:
          'فاکتور شماره ${faDigits(s.number)} حذف شود؟ موجودی انبار به حالت قبل برمی‌گردد.',
      confirmLabel: 'حذف',
      danger: true,
    )) {
      return;
    }
    if (!mounted) return;
    if (tryRun(context, () => context.svc.invoices.delete(s.id))) {
      toast(context, 'فاکتور حذف شد.');
      Navigator.pop(context, true);
    }
  }

  Future<void> _pdf({required bool print}) async {
    final x = d!;
    final svc = context.svc;
    try {
      final st = svc.settings;
      final mobile = x.summary.partyId == null
          ? ''
          : (svc.parties.get(x.summary.partyId!)?.mobile ?? '');
      final bytes = await PdfExport.invoice(
        x,
        business: {
          'name': st.get('business_name'),
          'phone': st.get('business_phone'),
          'address': st.get('business_address'),
          'footer': st.get('invoice_footer'),
        },
        partyMobile: mobile,
      );
      final name = 'invoice-${x.summary.kind}-${x.summary.number}.pdf';
      if (print) {
        final path = await FileService.writeTemp(name, bytes);
        final ok = await FileService.openPath(path);
        if (mounted) {
          toast(
            context,
            ok
                ? 'فایل PDF باز شد؛ از آن‌جا چاپ کنید.'
                : 'باز کردن PDF ممکن نشد: $path',
            error: !ok,
          );
        }
      } else {
        final path = await FileService.saveBytes(
          title: 'ذخیره فاکتور',
          fileName: name,
          ext: 'pdf',
          bytes: bytes,
        );
        if (path != null && mounted) toast(context, 'ذخیره شد: $path');
      }
    } catch (e) {
      if (mounted) toast(context, 'ساخت PDF ناموفق بود: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final x = d;
    if (x == null) {
      return const AppDialog(
        title: 'فاکتور',
        child: SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final s = x.summary;
    final cs = Theme.of(context).colorScheme;
    return AppDialog(
      title:
          '${s.isSale ? 'فاکتور فروش' : 'فاکتور خرید / هزینه'} شماره ${faDigits(s.number)}',
      width: 780,
      actions: [
        TextButton(
          onPressed: _delete,
          style: TextButton.styleFrom(foregroundColor: cs.error),
          child: const Text('حذف'),
        ),
        TextButton.icon(
          onPressed: () => _pdf(print: false),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('ذخیره PDF'),
        ),
        TextButton.icon(
          onPressed: () => _pdf(print: true),
          icon: const Icon(Icons.print_outlined),
          label: const Text('چاپ'),
        ),
        OutlinedButton.icon(
          onPressed: _edit,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('ویرایش'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, changed),
          child: const Text('بستن'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 24,
            runSpacing: 6,
            children: [
              Text('تاریخ: ${fmtJalaliLong(s.date)}'),
              Text(
                '${s.isSale ? 'مشتری' : 'طرف‌حساب'}: ${s.partyName.isEmpty ? 'متفرقه' : s.partyName}',
              ),
              StatusChip(
                payStatusLabel(s.status),
                statusColor(context, s.status),
              ),
            ],
          ),
          if ((s.description ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'توضیحات: ${s.description}',
                style: TextStyle(color: AppColors.muted(context)),
              ),
            ),
          const SizedBox(height: 12),
          _linesTable(context, x),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'جمع کل: ${fmtToman(s.total)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'پرداخت‌شده: ${fmtToman(s.paid)}',
                  style: TextStyle(color: AppColors.positive(context)),
                ),
                Text(
                  'باقی‌مانده: ${fmtToman(s.remaining)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: s.remaining > 0 ? AppColors.negative(context) : null,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 28),
          Row(
            children: [
              Text(
                s.isSale ? 'دریافت‌ها' : 'پرداخت‌ها',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (s.remaining > 0)
                FilledButton.tonalIcon(
                  onPressed: _addPayment,
                  icon: const Icon(Icons.add),
                  label: Text(s.isSale ? 'ثبت دریافت' : 'ثبت پرداخت'),
                ),
            ],
          ),
          if (x.payments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'هنوز پرداختی ثبت نشده است.',
                style: TextStyle(color: AppColors.muted(context)),
              ),
            ),
          for (final p in x.payments)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${fmtToman(p.amount)} — ${kMethodLabels[p.method] ?? p.method}',
              ),
              subtitle: Text(
                '${fmtJalali(p.date)}${p.description.isNotEmpty ? ' • ${p.description}' : ''}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'حذف پرداخت',
                onPressed: () => _deletePayment(p),
              ),
            ),
        ],
      ),
    );
  }

  Widget _linesTable(BuildContext context, InvoiceDetail x) {
    final head = TextStyle(fontSize: 12, color: AppColors.muted(context));
    Widget cell(String t, {double? w, TextStyle? st, bool end = false}) {
      final txt = Text(
        t,
        style: st,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
      final aligned = Align(
        alignment: end
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: txt,
      );
      return w == null
          ? Expanded(child: aligned)
          : SizedBox(width: w, child: aligned);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line(context)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                cell('ردیف', w: 40, st: head),
                cell('شرح', st: head),
                cell('تعداد', w: 70, st: head, end: true),
                cell('قیمت واحد', w: 110, st: head, end: true),
                cell('تخفیف', w: 90, st: head, end: true),
                cell('مبلغ', w: 110, st: head, end: true),
              ],
            ),
          ),
          const Divider(height: 1),
          for (var i = 0; i < x.lines.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  cell(faDigits(i + 1), w: 40),
                  cell(x.lines[i].title),
                  cell(fmtQty(x.lines[i].qty), w: 70, end: true),
                  cell(fmtMoney(x.lines[i].unitPrice), w: 110, end: true),
                  cell(fmtMoney(x.lines[i].discount), w: 90, end: true),
                  cell(
                    fmtMoney(x.lines[i].lineTotal),
                    w: 110,
                    st: const TextStyle(fontWeight: FontWeight.w700),
                    end: true,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
