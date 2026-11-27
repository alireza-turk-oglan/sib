import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/jalali.dart';
import 'common.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// انتخاب‌گر تاریخ شمسی؛ DateTime میلادی (فقط تاریخ) را برمی‌گرداند.
Future<DateTime?> showJalaliDatePicker(BuildContext context, {DateTime? initial, DateTime? first, DateTime? last}) =>
    showDialog<DateTime>(context: context, builder: (_) => _JalaliPickerDialog(initial: _day(initial ?? DateTime.now()), first: first, last: last));

class _JalaliPickerDialog extends StatefulWidget {
  final DateTime initial;
  final DateTime? first;
  final DateTime? last;
  const _JalaliPickerDialog({required this.initial, this.first, this.last});

  @override
  State<_JalaliPickerDialog> createState() => _JalaliPickerDialogState();
}

class _JalaliPickerDialogState extends State<_JalaliPickerDialog> {
  late int year;
  late int month;
  late DateTime selected;

  @override
  void initState() {
    super.initState();
    selected = widget.initial;
    final j = Jalali.fromDate(selected);
    year = j.year;
    month = j.month;
  }

  void _shift(int delta) {
    final j = Jalali(year, month, 1).addMonths(delta);
    setState(() {
      year = j.year;
      month = j.month;
    });
  }

  Future<void> _chooseYear(List<int> years) async {
    final y = await showDialog<int>(context: context, builder: (_) => _YearDialog(years: years, current: year));
    if (y != null) setState(() => year = y);
  }

  bool _enabled(DateTime d) {
    if (widget.first != null && d.isBefore(_day(widget.first!))) return false;
    if (widget.last != null && d.isAfter(_day(widget.last!))) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final today = _day(DateTime.now());
    final firstOfMonth = Jalali(year, month, 1).toDate();
    final offset = weekdaySat(firstOfMonth);
    final len = jalaliMonthLength(year, month);
    final weeks = ((offset + len) / 7).ceil();
    final nowYear = Jalali.now().year;
    final years = [for (var y = nowYear - 40; y <= nowYear + 20; y++) y];
    if (!years.contains(year)) years.add(year);
    years.sort();

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              // در RTL آیکون chevron_left به‌صورت «›» (رو به راست) رسم می‌شود: ماه قبل سمت راست با فلش راست‌رو، ماه بعد سمت چپ با فلش چپ‌رو
              IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left), tooltip: 'ماه قبل'),
              Expanded(
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  DropdownButton<int>(
                    value: month,
                    underline: const SizedBox.shrink(),
                    items: [for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(Jalali.monthNames[m]))],
                    onChanged: (v) => setState(() => month = v ?? month),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _chooseYear(years),
                    icon: const Icon(Icons.arrow_drop_down),
                    label: Text(faDigits(year), style: const TextStyle(fontSize: 15)),
                  ),
                ]),
              ),
              IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right), tooltip: 'ماه بعد'),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              for (final w in ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'])
                Expanded(child: Center(child: Text(w, style: TextStyle(color: AppColors.muted(context), fontWeight: FontWeight.w600)))),
            ]),
            const SizedBox(height: 4),
            for (var w = 0; w < weeks; w++)
              Row(children: [
                for (var c = 0; c < 7; c++) Expanded(child: _cell(context, cs, today, w * 7 + c - offset + 1, len)),
              ]),
            const SizedBox(height: 10),
            Row(children: [
              TextButton(
                onPressed: () {
                  final t = today;
                  final j = Jalali.fromDate(t);
                  setState(() {
                    selected = t;
                    year = j.year;
                    month = j.month;
                  });
                },
                child: const Text('امروز'),
              ),
              const Spacer(),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
              const SizedBox(width: 6),
              FilledButton(onPressed: _enabled(selected) ? () => Navigator.pop(context, selected) : null, child: const Text('تأیید')),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _cell(BuildContext context, ColorScheme cs, DateTime today, int day, int len) {
    if (day < 1 || day > len) return const SizedBox(height: 40);
    final d = Jalali(year, month, day).toDate();
    final isSel = d == selected;
    final isToday = d == today;
    final en = _enabled(d);
    return Padding(
      padding: const EdgeInsets.all(2),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: en ? () => setState(() => selected = d) : null,
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSel ? cs.primary : null,
            borderRadius: BorderRadius.circular(10),
            border: isToday && !isSel ? Border.all(color: cs.primary) : null,
          ),
          child: Text(
            faDigits(day),
            style: TextStyle(color: isSel ? cs.onPrimary : (en ? null : AppColors.muted(context).withAlpha(90)), fontWeight: isToday ? FontWeight.w700 : null),
          ),
        ),
      ),
    );
  }
}

/// انتخاب سال با لیست قابل‌اسکرول؛ نوار اسکرول عمداً سمت راست اعداد است (در RTL پیش‌فرض سمت چپ می‌افتد).
class _YearDialog extends StatefulWidget {
  final List<int> years;
  final int current;
  const _YearDialog({required this.years, required this.current});

  @override
  State<_YearDialog> createState() => _YearDialogState();
}

class _YearDialogState extends State<_YearDialog> {
  static const double _item = 44;
  late final ScrollController _c = ScrollController(initialScrollOffset: math.max(0, (widget.years.indexOf(widget.current) - 3) * _item));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('انتخاب سال'),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      content: SizedBox(
        width: 240,
        height: 300,
        child: Scrollbar(
          controller: _c,
          thumbVisibility: true,
          scrollbarOrientation: ScrollbarOrientation.right,
          child: ListView.builder(
            controller: _c,
            itemExtent: _item,
            itemCount: widget.years.length,
            itemBuilder: (context, i) {
              final y = widget.years[i];
              final sel = y == widget.current;
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.pop(context, y),
                child: Container(
                  alignment: Alignment.center,
                  margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(color: sel ? cs.primaryContainer : null, borderRadius: BorderRadius.circular(10)),
                  child: Text(faDigits(y), style: TextStyle(fontSize: 16, fontWeight: sel ? FontWeight.w700 : FontWeight.w400, color: sel ? cs.onPrimaryContainer : null)),
                ),
              );
            },
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف'))],
    );
  }
}

/// فیلد تاریخ شمسی (فقط‌خواندنی؛ با کلیک انتخاب‌گر باز می‌شود)
class JalaliDateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool clearable;
  final DateTime? first;
  final DateTime? last;
  const JalaliDateField({super.key, required this.label, required this.value, required this.onChanged, this.clearable = false, this.first, this.last});

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          final d = await showJalaliDatePicker(context, initial: value, first: first, last: last);
          if (d != null) onChanged(d);
        },
        child: InputDecorator(
          decoration: deco(
            label,
            suffix: clearable && value != null
                ? IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => onChanged(null), tooltip: 'پاک کردن')
                : const Icon(Icons.calendar_month_outlined, size: 20),
          ),
          child: Text(value == null ? '—' : fmtJalali(isoDate(value!))),
        ),
      );
}

/// دو فیلد «از تاریخ / تا تاریخ» + دکمه‌های بازه آماده
class DateRangeBar extends StatelessWidget {
  final DateRange range;
  final ValueChanged<DateRange> onChanged;
  const DateRangeBar({super.key, required this.range, required this.onChanged});

  @override
  Widget build(BuildContext context) => Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: 170,
          child: JalaliDateField(label: 'از تاریخ', value: range.from, onChanged: (d) {
            if (d == null) return;
            onChanged(DateRange(d, d.isAfter(range.to) ? d : range.to));
          }),
        ),
        SizedBox(
          width: 170,
          child: JalaliDateField(label: 'تا تاریخ', value: range.to, onChanged: (d) {
            if (d == null) return;
            onChanged(DateRange(d.isBefore(range.from) ? d : range.from, d));
          }),
        ),
        _chip('امروز', () => onChanged(DateRange.today())),
        _chip('این هفته', () => onChanged(DateRange.thisWeek())),
        _chip('این ماه', () => onChanged(DateRange.thisJalaliMonth())),
        _chip('۳۰ روز اخیر', () => onChanged(DateRange.lastDays(30))),
        _chip('امسال', () => onChanged(DateRange.thisJalaliYear())),
      ]);

  Widget _chip(String t, VoidCallback f) => ActionChip(label: Text(t), onPressed: f);
}
