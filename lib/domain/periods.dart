import '../core/utils/format.dart';
import '../core/utils/jalali.dart';

enum Granularity { day, week, month, year }

String granularityLabel(Granularity g) => switch (g) {
  Granularity.day => 'روزانه',
  Granularity.week => 'هفتگی',
  Granularity.month => 'ماهانه',
  Granularity.year => 'سالانه',
};

/// کلید مرتب‌شونده + برچسب نمایشی دوره شمسی برای یک تاریخ
class PeriodKey {
  final String key;
  final String label;
  const PeriodKey(this.key, this.label);
}

PeriodKey periodOf(DateTime d, Granularity g) {
  final j = Jalali.fromDate(d);
  switch (g) {
    case Granularity.day:
      return PeriodKey(isoDate(d), faDigits(j.toString()));
    case Granularity.week:
      final start = DateTime(d.year, d.month, d.day - weekdaySat(d));
      return PeriodKey(
        isoDate(start),
        'هفته از ${faDigits(Jalali.fromDate(start).toString())}',
      );
    case Granularity.month:
      return PeriodKey(
        '${j.year}-${j.month.toString().padLeft(2, '0')}',
        '${Jalali.monthNames[j.month]} ${faDigits(j.year)}',
      );
    case Granularity.year:
      return PeriodKey('${j.year}', faDigits(j.year));
  }
}
