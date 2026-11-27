import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'schema.dart';

/// خطای قابل‌نمایش به کاربر (پیام فارسی)
class DomainError implements Exception {
  final String message;
  DomainError(this.message);
  @override
  String toString() => message;
}

typedef DbRow = Map<String, Object?>;

/// پوشش نازک روی SQLite: تراکنش، مهاجرت، بررسی سلامت. UI هرگز مستقیم به این کلاس دسترسی ندارد؛ فقط Repositoryها.
class AppDatabase {
  final Database _db;
  final String? path;
  int _depth = 0;
  bool _closed = false;
  bool get isClosed => _closed;
  AppDatabase._(this._db, this.path);

  static AppDatabase open(String path) {
    final db = AppDatabase._(sqlite3.open(path), path);
    try {
      db._configure(file: true);
      db._migrate();
    } catch (_) {
      db.close();
      rethrow;
    }
    return db;
  }

  static AppDatabase openMemory() {
    final db = AppDatabase._(sqlite3.openInMemory(), null);
    db._configure(file: false);
    db._migrate();
    return db;
  }

  void _configure({required bool file}) {
    _db.execute('PRAGMA foreign_keys = ON');
    _db.execute('PRAGMA busy_timeout = 5000');
    if (file) {
      _db.execute('PRAGMA journal_mode = WAL');
      _db.execute(
        'PRAGMA synchronous = FULL',
      ); // ایمن در برابر قطع ناگهانی برق/بستن برنامه
    }
  }

  int get userVersion =>
      _db.select('PRAGMA user_version').first.values.first as int;

  void _migrate() {
    final v = userVersion;
    if (v > kSchemaVersion) {
      throw DomainError(
        'این دیتابیس با نسخه جدیدتری از نرم‌افزار ساخته شده است؛ برنامه را به‌روزرسانی کنید.',
      );
    }
    for (var i = v; i < kMigrations.length; i++) {
      transaction(() {
        for (final s in kMigrations[i]) {
          _db.execute(s);
        }
        if (i == 0) {
          kDefaultSettings.forEach(
            (k, val) => _db.execute(
              'INSERT OR IGNORE INTO settings(key, value) VALUES(?, ?)',
              [k, val],
            ),
          );
        }
        _db.execute('PRAGMA user_version = ${i + 1}');
      });
    }
  }

  /// تراکنش اتمیک؛ تودرتو بودن مجاز است (تراکنش بیرونی تعیین‌کننده commit/rollback است).
  T transaction<T>(T Function() body) {
    if (_depth > 0) return body();
    _db.execute('BEGIN IMMEDIATE');
    _depth = 1;
    try {
      final r = body();
      _db.execute('COMMIT');
      return r;
    } catch (_) {
      try {
        _db.execute('ROLLBACK');
      } catch (_) {}
      rethrow;
    } finally {
      _depth = 0;
    }
  }

  List<DbRow> query(String sql, [List<Object?> params = const []]) {
    final rs = _db.select(sql, params);
    return [
      for (final r in rs) {for (final k in r.keys) k: r[k]},
    ];
  }

  DbRow? one(String sql, [List<Object?> params = const []]) {
    final r = query(sql, params);
    return r.isEmpty ? null : r.first;
  }

  Object? scalar(String sql, [List<Object?> params = const []]) {
    final rs = _db.select(sql, params);
    if (rs.isEmpty) return null;
    return rs.first.values.first;
  }

  int intScalar(String sql, [List<Object?> params = const []]) =>
      (scalar(sql, params) as int?) ?? 0;

  /// اجرای دستور نوشتنی؛ تعداد ردیف‌های تغییر‌یافته را برمی‌گرداند.
  int exec(String sql, [List<Object?> params = const []]) {
    try {
      _db.execute(sql, params);
    } on SqliteException catch (e) {
      throw translateSqlite(e);
    }
    return _db.updatedRows;
  }

  int get lastInsertId => _db.lastInsertRowId;

  /// نتیجه quick_check ('ok' یعنی سالم) + ناسازگاری کلید خارجی
  List<String> healthIssues() {
    final issues = <String>[];
    final qc = _db.select('PRAGMA quick_check');
    for (final r in qc) {
      final v = '${r.values.first}';
      if (v != 'ok') issues.add(v);
    }
    final fk = _db.select('PRAGMA foreign_key_check');
    if (fk.isNotEmpty) issues.add('ناسازگاری کلید خارجی در ${fk.length} ردیف');
    return issues;
  }

  /// نسخه کامل و سازگار از دیتابیس در یک فایل (حتی هنگام استفاده)
  void vacuumInto(String targetPath) {
    final f = File(targetPath);
    if (f.existsSync()) f.deleteSync();
    _db.execute('VACUUM INTO ?', [targetPath]);
  }

  void checkpoint() {
    try {
      _db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (_) {}
  }

  void close() {
    if (_closed) return;
    _closed = true;
    checkpoint();
    // sqlite3 نسخه ۳: close() ؛ نسخه‌های ۲: dispose() — هر دو پشتیبانی می‌شوند
    final dynamic raw = _db;
    try {
      raw.close();
    } on NoSuchMethodError {
      raw.dispose();
    }
  }
}

/// تبدیل خطای SQLite/تریگر به پیام فارسی
DomainError translateSqlite(SqliteException e) {
  final m = e.message;
  if (m.contains('overpay')) {
    return DomainError('مبلغ پرداخت از مانده فاکتور بیشتر است.');
  }
  if (m.contains('total_below_paid')) {
    return DomainError(
      'مبلغ جدید فاکتور کمتر از مجموع پرداخت‌های ثبت‌شده آن است.',
    );
  }
  if (m.contains('has_payments')) {
    return DomainError(
      'این فاکتور پرداخت ثبت‌شده دارد؛ ابتدا پرداخت‌ها را حذف کنید.',
    );
  }
  if (m.contains('direction_mismatch') || m.contains('party_mismatch')) {
    return DomainError('پرداخت با نوع یا طرف‌حساب فاکتور هم‌خوان نیست.');
  }
  if (m.contains('invoice_not_found')) {
    return DomainError('فاکتور پیدا نشد یا حذف شده است.');
  }
  if (m.contains('UNIQUE') && m.contains('parties.mobile')) {
    return DomainError('این شماره موبایل قبلاً ثبت شده است.');
  }
  if (m.contains('UNIQUE') && m.contains('.code')) {
    return DomainError('این کد قبلاً استفاده شده است.');
  }
  if (m.contains('UNIQUE') && m.contains('invoices')) {
    return DomainError('شماره فاکتور تکراری است.');
  }
  if (m.contains('UNIQUE') && m.contains('categories')) {
    return DomainError('این دسته‌بندی قبلاً وجود دارد.');
  }
  if (m.contains('FOREIGN KEY')) {
    return DomainError('این مورد به اطلاعات دیگری وابسته است.');
  }
  if (m.contains('CHECK')) return DomainError('مقدار واردشده معتبر نیست.');
  return DomainError('خطای پایگاه داده: $m');
}
