import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/format.dart';
import 'common.dart';

/// ورودی مبلغ: ارقام فارسی/عربی را لاتین می‌کند و جداکننده هزارگان می‌گذارد (حداکثر ۱۲ رقم).
class MoneyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = enDigits(newValue.text).replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    if (digits.length > 12) return oldValue;
    final text = groupThousands(int.parse(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// ورودی مقدار: ارقام و یک ممیز با حداکثر ۳ رقم اعشار
class QtyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var t = enDigits(
      newValue.text,
    ).replaceAll('٫', '.').replaceAll('،', '.').replaceAll(',', '.');
    t = t.replaceAll(RegExp(r'[^0-9.]'), '');
    final first = t.indexOf('.');
    if (first >= 0) {
      t =
          t.substring(0, first + 1) +
          t.substring(first + 1).replaceAll('.', '');
    }
    if (RegExp(r'^\d{0,6}(\.\d{0,3})?$').hasMatch(t) == false) return oldValue;
    return TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }
}

class MoneyField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool required;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final String suffixText;
  const MoneyField({
    super.key,
    required this.controller,
    required this.label,
    this.required = true,
    this.enabled = true,
    this.onChanged,
    this.suffixText = 'تومان',
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    enabled: enabled,
    keyboardType: TextInputType.number,
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.right,
    inputFormatters: [MoneyInputFormatter()],
    decoration: deco(label, suffixText: suffixText),
    onChanged: onChanged,
    validator: (v) {
      if (v == null || v.trim().isEmpty) {
        return required ? 'مبلغ را وارد کنید.' : null;
      }
      return parseMoney(v) == null ? 'مبلغ نامعتبر است.' : null;
    },
  );
}

class QtyField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool required;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  const QtyField({
    super.key,
    required this.controller,
    required this.label,
    this.required = true,
    this.enabled = true,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    enabled: enabled,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.right,
    inputFormatters: [QtyInputFormatter()],
    decoration: deco(label),
    onChanged: onChanged,
    validator: (v) {
      if (v == null || v.trim().isEmpty) {
        return required ? 'مقدار را وارد کنید.' : null;
      }
      final q = parseQty(v);
      if (q == null) return 'مقدار نامعتبر است.';
      return null;
    },
  );
}

/// نمایش مبلغ ورودی به‌صورت متن (برای کنترلرهای MoneyField)
int moneyOf(TextEditingController c) => parseMoney(c.text) ?? 0;
