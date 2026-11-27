/// تقویم شمسی (الگوریتم حسابی ۳۳ ساله، سازگار با jdf). تاریخ‌ها در دیتابیس میلادی (ISO) ذخیره می‌شوند
/// و فقط در لایه نمایش به شمسی تبدیل می‌شوند.
class Jalali {
  final int year;
  final int month;
  final int day;
  const Jalali(this.year, this.month, this.day);

  static const monthNames = [
    '',
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];
  // ایندکس ۰ = شنبه
  static const weekdayNames = [
    'شنبه',
    'یکشنبه',
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
    'پنجشنبه',
    'جمعه',
  ];

  factory Jalali.fromDate(DateTime d) {
    final r = gregorianToJalali(d.year, d.month, d.day);
    return Jalali(r[0], r[1], r[2]);
  }
  factory Jalali.now() => Jalali.fromDate(DateTime.now());

  DateTime toDate() {
    final g = jalaliToGregorian(year, month, day);
    return DateTime(g[0], g[1], g[2]);
  }

  /// رشته ISO میلادی (yyyy-MM-dd) برای ذخیره و جست‌وجو در دیتابیس
  String toIso() => isoDate(toDate());

  int get monthLength => jalaliMonthLength(year, month);

  Jalali addMonths(int n) {
    var idx = year * 12 + (month - 1) + n;
    final y = idx ~/ 12;
    final m = idx % 12 + 1;
    final len = jalaliMonthLength(y, m);
    return Jalali(y, m, day > len ? len : day);
  }

  @override
  bool operator ==(Object other) =>
      other is Jalali &&
      other.year == year &&
      other.month == month &&
      other.day == day;
  @override
  int get hashCode => year * 10000 + month * 100 + day;
  @override
  String toString() => '$year/${_p2(month)}/${_p2(day)}';
}

String _p2(int n) => n.toString().padLeft(2, '0');
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_p2(d.month)}-${_p2(d.day)}';

/// تبدیل رشته ISO (yyyy-MM-dd یا yyyy-MM-ddTHH:mm...) به DateTime محلی (فقط تاریخ)
DateTime? parseIso(String? s) {
  if (s == null || s.length < 10) return null;
  final y = int.tryParse(s.substring(0, 4));
  final m = int.tryParse(s.substring(5, 7));
  final d = int.tryParse(s.substring(8, 10));
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

List<int> gregorianToJalali(int gy, int gm, int gd) {
  const gdm = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
  final gy2 = gm > 2 ? gy + 1 : gy;
  var days =
      355666 +
      365 * gy +
      (gy2 + 3) ~/ 4 -
      (gy2 + 99) ~/ 100 +
      (gy2 + 399) ~/ 400 +
      gd +
      gdm[gm - 1];
  var jy = -1595 + 33 * (days ~/ 12053);
  days %= 12053;
  jy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    jy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  final int jm;
  final int jd;
  if (days < 186) {
    jm = 1 + days ~/ 31;
    jd = 1 + days % 31;
  } else {
    jm = 7 + (days - 186) ~/ 30;
    jd = 1 + (days - 186) % 30;
  }
  return [jy, jm, jd];
}

List<int> jalaliToGregorian(int jy, int jm, int jd) {
  jy += 1595;
  var days =
      -355668 +
      365 * jy +
      (jy ~/ 33) * 8 +
      ((jy % 33) + 3) ~/ 4 +
      jd +
      (jm < 7 ? (jm - 1) * 31 : (jm - 7) * 30 + 186);
  var gy = 400 * (days ~/ 146097);
  days %= 146097;
  if (days > 36524) {
    days--;
    gy += 100 * (days ~/ 36524);
    days %= 36524;
    if (days >= 365) days++;
  }
  gy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    gy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  var gd = days + 1;
  final leap = (gy % 4 == 0 && gy % 100 != 0) || gy % 400 == 0;
  final sal = [0, 31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  var gm = 0;
  while (gm < 13 && gd > sal[gm]) {
    gd -= sal[gm];
    gm++;
  }
  return [gy, gm, gd];
}

bool isJalaliLeap(int jy) {
  final g = jalaliToGregorian(jy, 12, 30);
  final back = gregorianToJalali(g[0], g[1], g[2]);
  return back[0] == jy && back[1] == 12 && back[2] == 30;
}

int jalaliMonthLength(int jy, int jm) {
  if (jm <= 6) return 31;
  if (jm <= 11) return 30;
  return isJalaliLeap(jy) ? 30 : 29;
}

/// ایندکس روز هفته با شروع از شنبه (شنبه=۰ ... جمعه=۶)
int weekdaySat(DateTime d) =>
    (d.weekday + 1) % 7; // DateTime: Mon=1..Sun=7 -> Sat=0

/// بازه‌های زمانی پرکاربرد (همگی با تاریخ ISO میلادی و شامل ابتدا و انتها)
class DateRange {
  final DateTime from;
  final DateTime to;
  const DateRange(this.from, this.to);
  String get fromIso => isoDate(from);
  String get toIso => isoDate(to);

  static DateRange today([DateTime? now]) {
    final n = _day(now ?? DateTime.now());
    return DateRange(n, n);
  }

  static DateRange thisWeek([DateTime? now]) {
    final n = _day(now ?? DateTime.now());
    final start = DateTime(n.year, n.month, n.day - weekdaySat(n));
    return DateRange(start, DateTime(start.year, start.month, start.day + 6));
  }

  static DateRange thisJalaliMonth([DateTime? now]) {
    final j = Jalali.fromDate(now ?? DateTime.now());
    return jalaliMonth(j.year, j.month);
  }

  static DateRange jalaliMonth(int y, int m) => DateRange(
    Jalali(y, m, 1).toDate(),
    Jalali(y, m, jalaliMonthLength(y, m)).toDate(),
  );

  static DateRange thisJalaliYear([DateTime? now]) {
    final j = Jalali.fromDate(now ?? DateTime.now());
    return DateRange(
      Jalali(j.year, 1, 1).toDate(),
      Jalali(j.year, 12, jalaliMonthLength(j.year, 12)).toDate(),
    );
  }

  static DateRange lastDays(int n, [DateTime? now]) {
    final t = _day(now ?? DateTime.now());
    return DateRange(DateTime(t.year, t.month, t.day - (n - 1)), t);
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
}
