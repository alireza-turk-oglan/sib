import 'dart:io';
import 'dart:typed_data';

import '../core/utils/format.dart';
import 'backup_format.dart';
import 'database.dart';
import 'repos/settings_repo.dart';
import 'schema.dart';

class BackupInfo {
  final String path;
  final BackupMeta meta;
  const BackupInfo(this.path, this.meta);
}

class BackupFileEntry {
  final String path;
  final int size;
  final DateTime modified;
  const BackupFileEntry(this.path, this.size, this.modified);
  String get name => path.split(RegExp(r'[\\/]')).last;
}

String _p2(int n) => n.toString().padLeft(2, '0');
String backupFileName(DateTime t, {String prefix = 'sib-backup'}) =>
    '$prefix-${t.year}${_p2(t.month)}${_p2(t.day)}-${_p2(t.hour)}${_p2(t.minute)}${_p2(t.second)}.sibbak';

/// پشتیبان‌گیری و بازیابی ایمن. همه مراحل اعتبارسنجی دارند و فایل فعلی تا آخرین لحظه دست‌نخورده می‌ماند.
class BackupService {
  /// اندازه‌گیری تعداد رکوردهای مهم برای نمایش هنگام بازیابی
  static Map<String, int> _counts(AppDatabase db) => {
    'customers': db.intScalar(
      "SELECT COUNT(*) FROM parties WHERE kind='customer' AND deleted_at IS NULL",
    ),
    'suppliers': db.intScalar(
      "SELECT COUNT(*) FROM parties WHERE kind='supplier' AND deleted_at IS NULL",
    ),
    'items': db.intScalar(
      'SELECT COUNT(*) FROM items WHERE deleted_at IS NULL',
    ),
    'invoices': db.intScalar(
      'SELECT COUNT(*) FROM invoices WHERE deleted_at IS NULL',
    ),
    'payments': db.intScalar(
      'SELECT COUNT(*) FROM payments WHERE deleted_at IS NULL',
    ),
  };

  /// پشتیبان کامل در پوشه dir. فایل ابتدا به‌صورت موقت نوشته، بازخوانی و اعتبارسنجی و سپس نام‌گذاری می‌شود.
  static BackupInfo create(
    AppDatabase db,
    String dir, {
    required String appVersion,
    SettingsRepo? settings,
    DateTime? now,
    String prefix = 'sib-backup',
  }) {
    final t = now ?? DateTime.now();
    final d = Directory(dir);
    if (!d.existsSync()) d.createSync(recursive: true);
    final snap =
        '$dir${Platform.pathSeparator}.snapshot-${t.microsecondsSinceEpoch}.tmp';
    final tmp =
        '$dir${Platform.pathSeparator}.backup-${t.microsecondsSinceEpoch}.part';
    try {
      db.vacuumInto(snap);
      final bytes = packBackup(
        Uint8List.fromList(File(snap).readAsBytesSync()),
        schemaVersion: db.userVersion,
        appVersion: appVersion,
        createdAtIso: t.toUtc().toIso8601String(),
        counts: _counts(db),
      );
      File(tmp).writeAsBytesSync(bytes, flush: true);
      // بازخوانی و اعتبارسنجی فایل نوشته‌شده
      final check = unpackBackup(
        Uint8List.fromList(File(tmp).readAsBytesSync()),
        maxSchemaVersion: kSchemaVersion,
      );
      var finalPath =
          '$dir${Platform.pathSeparator}${backupFileName(t, prefix: prefix)}';
      var n = 1;
      while (File(finalPath).existsSync()) {
        finalPath =
            '$dir${Platform.pathSeparator}${backupFileName(t, prefix: prefix).replaceFirst('.sibbak', '-${n++}.sibbak')}';
      }
      File(tmp).renameSync(finalPath);
      settings?.set('last_backup_at', nowIsoUtc());
      return BackupInfo(finalPath, check.meta);
    } finally {
      for (final f in [snap, tmp]) {
        try {
          if (File(f).existsSync()) File(f).deleteSync();
        } catch (_) {}
      }
    }
  }

  /// فقط اعتبارسنجی و خواندن متادیتا (برای نمایش به کاربر پیش از بازیابی)
  static BackupInfo inspect(String path) {
    final f = File(path);
    if (!f.existsSync()) throw BackupFormatException('فایل پیدا نشد.');
    final u = unpackBackup(
      Uint8List.fromList(f.readAsBytesSync()),
      maxSchemaVersion: kSchemaVersion,
    );
    return BackupInfo(path, u.meta);
  }

  /// بازیابی. [current] دیتابیس باز فعلی است و در این تابع بسته می‌شود؛ مسیر خروجی دیتابیس جدید است و باید دوباره باز شود.
  /// مراحل: اعتبارسنجی فایل → ساخت فایل موقت و بررسی سلامت/مهاجرت → پشتیبان ایمنی از وضعیت فعلی → جایگزینی.
  static void restore({
    required String backupPath,
    required AppDatabase current,
    required String safetyDir,
    required String appVersion,
  }) {
    final dbPath = current.path;
    if (dbPath == null) {
      throw BackupFormatException('بازیابی روی دیتابیس موقت ممکن نیست.');
    }
    final u = unpackBackup(
      Uint8List.fromList(File(backupPath).readAsBytesSync()),
      maxSchemaVersion: kSchemaVersion,
    );

    final staged = '$dbPath.restoring';
    try {
      File(staged).writeAsBytesSync(u.db, flush: true);
      final probe = AppDatabase.open(
        staged,
      ); // مهاجرت نسخه‌های قدیمی‌تر + بررسی باز شدن
      final issues = probe.healthIssues();
      probe.close();
      if (issues.isNotEmpty) {
        throw BackupFormatException(
          'دیتابیس داخل پشتیبان سالم نیست: ${issues.first}',
        );
      }
    } catch (e) {
      _rm(staged);
      _rm('$staged-wal');
      _rm('$staged-shm');
      rethrow;
    }

    // پشتیبان ایمنی از وضعیت فعلی (قبل از هر تغییری)
    create(
      current,
      safetyDir,
      appVersion: appVersion,
      prefix: 'sib-before-restore',
    );

    current.close();
    _rm('$dbPath-wal');
    _rm('$dbPath-shm');
    final old = '$dbPath.old';
    try {
      _rm(old);
      if (File(dbPath).existsSync()) File(dbPath).renameSync(old);
      File(staged).renameSync(dbPath);
      _rm('$staged-wal');
      _rm('$staged-shm');
      _rm(old);
    } catch (e) {
      // بازگرداندن فایل قبلی اگر جایگزینی ناقص ماند
      try {
        if (!File(dbPath).existsSync() && File(old).existsSync()) {
          File(old).renameSync(dbPath);
        }
      } catch (_) {}
      throw BackupFormatException(
        'جایگزینی فایل دیتابیس ناموفق بود؛ اطلاعات قبلی حفظ شد. ($e)',
      );
    }
  }

  static void _rm(String p) {
    try {
      final f = File(p);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  static List<BackupFileEntry> list(String dir) {
    final d = Directory(dir);
    if (!d.existsSync()) return [];
    final out = <BackupFileEntry>[];
    for (final e in d.listSync(followLinks: false)) {
      if (e is File && e.path.toLowerCase().endsWith('.sibbak')) {
        final st = e.statSync();
        out.add(BackupFileEntry(e.path, st.size, st.modified));
      }
    }
    out.sort((a, b) => b.modified.compareTo(a.modified));
    return out;
  }

  /// نگه‌داشتن فقط n پشتیبان آخر در یک پوشه (برای پشتیبان خودکار)
  static void prune(String dir, {int keep = 7}) {
    final l = list(dir);
    for (var i = keep; i < l.length; i++) {
      _rm(l[i].path);
    }
  }
}
