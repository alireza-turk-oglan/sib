import 'jalali.dart';

const _faDigits = '۰۱۲۳۴۵۶۷۸۹';
const _arDigits = '٠١٢٣٤٥٦٧٨٩';

/// اعداد لاتین ← فارسی
String faDigits(Object? v) {
  final s = v?.toString() ?? '';
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    final i = '0123456789'.indexOf(c);
    b.write(i >= 0 ? _faDigits[i] : c);
  }
  return b.toString();
}

/// اعداد فارسی/عربی ← لاتین (برای ورودی کاربر)
String enDigits(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    var i = _faDigits.indexOf(c);
    if (i < 0) i = _arDigits.indexOf(c);
    b.write(i >= 0 ? '$i' : c);
  }
  return b.toString();
}

/// جداکننده هزارگان؛ sep پیش‌فرض ',' (برای فیلدهای ورودی) و '٬' برای نمایش فارسی
String groupThousands(int n, {String sep = ','}) {
  final neg = n < 0;
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(sep);
    b.write(s[i]);
  }
  return (neg ? '-' : '') + b.toString();
}

/// مبلغ برای نمایش: ۱٬۲۵۰٬۰۰۰
String fmtMoney(num n) => faDigits(groupThousands(n.round(), sep: '٬'));

/// مبلغ با واحد: ۱٬۲۵۰٬۰۰۰ تومان
String fmtToman(num n) => '${fmtMoney(n)} تومان';

/// تعداد/مقدار با حداکثر ۳ رقم اعشار بدون صفرهای اضافه
String fmtQty(num q) {
  var s = q.toStringAsFixed(3);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return faDigits(s.replaceAll('.', '٫'));
}

/// ورودی مبلغ کاربر (با ارقام فارسی، جداکننده و ...) ← عدد صحیح. null اگر نامعتبر.
int? parseMoney(String s) {
  final t = enDigits(s).replaceAll(RegExp(r'[,٬،\s]'), '');
  if (t.isEmpty) return null;
  if (!RegExp(r'^\d{1,15}$').hasMatch(t)) return null;
  return int.parse(t);
}

/// ورودی مقدار (اعشار با . یا ٫) ← double. null اگر نامعتبر.
double? parseQty(String s) {
  final t = enDigits(
    s,
  ).replaceAll('٫', '.').replaceAll('،', '.').replaceAll(RegExp(r'\s'), '');
  if (t.isEmpty || !RegExp(r'^\d{1,9}(\.\d{1,3})?$').hasMatch(t)) return null;
  return double.parse(t);
}

/// 09xxxxxxxxx یا null اگر نامعتبر
String? normalizeMobile(String s) {
  var p = enDigits(s).replaceAll(RegExp(r'[\s\-]'), '');
  if (p.startsWith('+98')) {
    p = '0${p.substring(3)}';
  } else if (p.startsWith('0098')) {
    p = '0${p.substring(4)}';
  } else if (RegExp(r'^9\d{9}$').hasMatch(p)) {
    p = '0$p';
  }
  return RegExp(r'^09\d{9}$').hasMatch(p) ? p : null;
}

/// تاریخ ISO ← شمسی با ارقام فارسی (۱۴۰۵/۰۸/۱۶)
String fmtJalali(String? iso) {
  final d = parseIso(iso);
  if (d == null) return '—';
  return faDigits(Jalali.fromDate(d).toString());
}

String fmtJalaliLong(String? iso) {
  final d = parseIso(iso);
  if (d == null) return '—';
  final j = Jalali.fromDate(d);
  return '${Jalali.weekdayNames[weekdaySat(d)]} ${faDigits(j.day)} ${Jalali.monthNames[j.month]} ${faDigits(j.year)}';
}

/// زمان UTC دیتابیس/سرور (ISO-8601) ← «۱۴۰۵/۰۸/۱۶ ۱۴:۳۰» به وقت محلی
String fmtJalaliDateTime(String? isoUtc) {
  if (isoUtc == null || isoUtc.isEmpty) return '—';
  final dt = DateTime.tryParse(isoUtc);
  if (dt == null) return '—';
  final l = dt.toLocal();
  final hh = l.hour.toString().padLeft(2, '0');
  final mm = l.minute.toString().padLeft(2, '0');
  return faDigits('${Jalali.fromDate(l)} $hh:$mm');
}

String nowIsoUtc() => DateTime.now().toUtc().toIso8601String();

/// یکدست‌سازی حروف عربی/فارسی و فاصله‌ها برای ذخیره و جست‌وجو (ي→ی ، ك→ک ، فاصله‌های اضافه)
String normalizeFa(String s) {
  return s
      .replaceAll('ي', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll('ى', 'ی')
      .replaceAll(RegExp(r'[\u200B\u200E\u200F]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// عدد کوتاه‌شده برای محور نمودار: ۱٫۵ میلیون ، ۲۵۰ هزار
String fmtShort(double v) {
  String t(double x) {
    var s = x.toStringAsFixed(1);
    if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
    return faDigits(s.replaceAll('.', '٫'));
  }

  final a = v.abs();
  final sign = v < 0 ? '-' : '';
  if (a >= 1e9) return '$sign${t(a / 1e9)} میلیارد';
  if (a >= 1e6) return '$sign${t(a / 1e6)} میلیون';
  if (a >= 1e3) return '$sign${t(a / 1e3)} هزار';
  return '$sign${faDigits(a.round())}';
}
