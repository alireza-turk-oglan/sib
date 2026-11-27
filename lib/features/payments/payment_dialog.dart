import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/utils/format.dart';
import '../../core/utils/jalali.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/jalali_picker.dart';
import '../../data/models.dart';

/// ثبت دریافت/پرداخت. برای یک فاکتور (invoiceId + remaining) یا پرداخت عمومی طرف‌حساب (partyId).
/// true = ثبت شد.
Future<bool> showPaymentDialog(
  BuildContext context, {
  int? invoiceId,
  int? partyId,
  required String partyName,
  required bool
  incoming, // true: دریافت از مشتری ، false: پرداخت به تأمین‌کننده
  int? remaining,
  String? invoiceLabel,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => _PaymentDialog(
      invoiceId: invoiceId,
      partyId: partyId,
      partyName: partyName,
      incoming: incoming,
      remaining: remaining,
      invoiceLabel: invoiceLabel,
    ),
  );
  return r ?? false;
}

class _PaymentDialog extends StatefulWidget {
  final int? invoiceId;
  final int? partyId;
  final String partyName;
  final bool incoming;
  final int? remaining;
  final String? invoiceLabel;
  const _PaymentDialog({
    this.invoiceId,
    this.partyId,
    required this.partyName,
    required this.incoming,
    this.remaining,
    this.invoiceLabel,
  });

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _amount;
  final _desc = TextEditingController();
  String _method = 'cash';
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: widget.remaining != null && widget.remaining! > 0
          ? groupThousands(widget.remaining!)
          : '',
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final ok = tryRun(context, () {
      context.svc.payments.add(
        invoiceId: widget.invoiceId,
        partyId: widget.partyId,
        method: _method,
        amount: moneyOf(_amount),
        date: isoDate(_date),
        description: _desc.text,
      );
    });
    if (ok) {
      toast(context, widget.incoming ? 'دریافت ثبت شد.' : 'پرداخت ثبت شد.');
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rem = widget.remaining;
    return AppDialog(
      title: widget.incoming ? 'ثبت دریافت' : 'ثبت پرداخت',
      width: 440,
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
            Text(
              '${widget.incoming ? 'از' : 'به'}: ${widget.partyName.isEmpty ? 'متفرقه' : widget.partyName}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (widget.invoiceLabel != null) Text(widget.invoiceLabel!),
            if (widget.invoiceId == null)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'پرداخت عمومی (بدون فاکتور): در مانده حساب لحاظ می‌شود و بعداً می‌توان به فاکتور اختصاص داد.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            const SizedBox(height: 14),
            MoneyField(controller: _amount, label: 'مبلغ'),
            if (rem != null && rem > 0)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () =>
                      setState(() => _amount.text = groupThousands(rem)),
                  child: Text('تسویه کامل: ${fmtToman(rem)}'),
                ),
              ),
            const SizedBox(height: 10),
            DropdownField<String>(
              label: 'روش',
              value: _method,
              items: [
                for (final e in kMethodLabels.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _method = v ?? 'cash'),
            ),
            const SizedBox(height: 12),
            JalaliDateField(
              label: 'تاریخ',
              value: _date,
              onChanged: (d) => setState(() => _date = d ?? _date),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _desc,
              maxLength: 300,
              decoration: deco('توضیحات (اختیاری)'),
            ),
          ],
        ),
      ),
    );
  }
}
