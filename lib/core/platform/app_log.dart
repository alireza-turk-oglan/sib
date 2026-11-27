import 'dart:io';

import 'app_paths.dart';

/// لاگ فایل روزانه (۳۰ روز اخیر نگه داشته می‌شود). هرگز اطلاعات حساس (توکن، کد پیامکی) را ننویسید.
class Log {
  Log._();

  static void info(String msg) => _write('INFO', msg);
  static void error(String msg, [Object? err, StackTrace? st]) => _write(
    'ERROR',
    '$msg${err != null ? ' | $err' : ''}${st != null ? '\n$st' : ''}',
  );

  static void _write(String level, String msg) {
    try {
      final t = DateTime.now();
      final day =
          '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
      File(
        '${AppPaths.logsDir}${Platform.pathSeparator}app-$day.log',
      ).writeAsStringSync(
        '${t.toIso8601String()} [$level] $msg\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // لاگ نباید باعث خرابی برنامه شود
    }
  }

  static void prune({int keepDays = 30}) {
    try {
      final limit = DateTime.now().subtract(Duration(days: keepDays));
      for (final e in Directory(AppPaths.logsDir).listSync()) {
        if (e is File && e.statSync().modified.isBefore(limit)) e.deleteSync();
      }
    } catch (_) {}
  }
}
