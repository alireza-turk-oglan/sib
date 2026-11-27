import 'package:flutter/material.dart';

import '../../domain/report_models.dart';
import '../theme/app_theme.dart';

double _colWidth(ReportColumn c, int index) => switch (c.type) {
  ColType.text => index <= 1 ? 200 : 170,
  ColType.money => 130,
  ColType.qty => 90,
  ColType.count => 90,
  ColType.date => 105,
  ColType.method => 110,
  ColType.direction => 90,
};

bool _numeric(ReportColumn c) =>
    c.type == ColType.money || c.type == ColType.qty || c.type == ColType.count;

/// جدول گزارش (سطر به سطر با بارگذاری تنبل). در عرض کم، افقی اسکرول می‌شود.
class ReportGrid extends StatelessWidget {
  final ReportTable table;
  const ReportGrid({super.key, required this.table});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, box) {
        final base = [
          for (var i = 0; i < table.columns.length; i++)
            _colWidth(table.columns[i], i),
        ];
        final sum = base.fold<double>(0, (a, b) => a + b);
        final avail = box.maxWidth.isFinite ? box.maxWidth : sum;
        final scale = sum < avail ? avail / sum : 1.0;
        final widths = [for (final w in base) w * scale];
        final total = sum < avail ? avail : sum;

        Widget row(
          List<Object?> cells, {
          bool header = false,
          bool bold = false,
          Color? bg,
          bool isTotals = false,
        }) {
          return Container(
            height: header ? 44 : 40,
            color: bg,
            child: Row(
              children: [
                for (var i = 0; i < table.columns.length; i++)
                  SizedBox(
                    width: widths[i],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Align(
                        alignment: _numeric(table.columns[i]) && !header
                            ? AlignmentDirectional.centerEnd
                            : AlignmentDirectional.centerStart,
                        child: Text(
                          header
                              ? table.columns[i].title
                              : formatCell(
                                  table.columns[i],
                                  i < cells.length ? cells[i] : null,
                                ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: (header || bold || isTotals)
                                ? FontWeight.w700
                                : FontWeight.w400,
                            fontSize: header ? 12.5 : 13.5,
                            color: header ? AppColors.muted(context) : null,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        final line = AppColors.line(context);
        final grid = SizedBox(
          width: total,
          child: Column(
            children: [
              row(
                const [],
                header: true,
                bg: cs.surfaceContainerHighest.withAlpha(120),
              ),
              Divider(height: 1, color: line),
              Expanded(
                child: table.rows.isEmpty
                    ? Center(
                        child: Text(
                          'داده‌ای برای نمایش وجود ندارد.',
                          style: TextStyle(color: AppColors.muted(context)),
                        ),
                      )
                    : ListView.builder(
                        itemCount: table.rows.length,
                        itemExtent: 40,
                        itemBuilder: (context, i) => row(
                          table.rows[i],
                          bold: table.boldRows.contains(i),
                          bg: table.boldRows.contains(i)
                              ? cs.primary.withAlpha(18)
                              : (i.isOdd ? cs.onSurface.withAlpha(6) : null),
                        ),
                      ),
              ),
              if (table.totals != null) ...[
                Divider(height: 1, color: line),
                row(
                  table.totals!,
                  isTotals: true,
                  bg: cs.surfaceContainerHighest.withAlpha(120),
                ),
              ],
            ],
          ),
        );

        final body = sum > avail
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: grid,
              )
            : grid;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: line),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: body,
          ),
        );
      },
    );
  }
}
