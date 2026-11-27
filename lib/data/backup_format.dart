import 'dart:convert';
import 'dart:typed_data';

import '../core/utils/sha256.dart';

/// فرمت فایل پشتیبان اختصاصی (.sibbak):
///   [8 بایت] SIBBAK01  |  [4 بایت] طول متادیتا (big-endian)  |  [متادیتا JSON/UTF-8]  |  [فایل SQLite]
/// متادیتا شامل نسخه ساختار دیتابیس و هش SHA-256 فایل است تا فایل خراب یا ناسازگار رد شود.
const String kBackupMagic = 'SIBBAK01';
const int kBackupFormatVersion = 1;
const String kBackupApp = 'sib-accounting';

class BackupFormatException implements Exception {
  final String message;
  BackupFormatException(this.message);
  @override
  String toString() => message;
}

class BackupMeta {
  final int formatVersion;
  final String app;
  final int schemaVersion;
  final String appVersion;
  final String createdAt; // ISO UTC
  final String dbSha256;
  final int dbSize;
  final Map<String, int> counts;
  const BackupMeta({
    this.formatVersion = kBackupFormatVersion,
    this.app = kBackupApp,
    required this.schemaVersion,
    required this.appVersion,
    required this.createdAt,
    required this.dbSha256,
    required this.dbSize,
    this.counts = const {},
  });

  Map<String, Object?> toJson() => {
    'formatVersion': formatVersion,
    'app': app,
    'schemaVersion': schemaVersion,
    'appVersion': appVersion,
    'createdAt': createdAt,
    'dbSha256': dbSha256,
    'dbSize': dbSize,
    'counts': counts,
  };

  factory BackupMeta.fromJson(Map<String, dynamic> j) {
    final counts = <String, int>{};
    final c = j['counts'];
    if (c is Map) {
      c.forEach((k, v) {
        if (v is int) counts['$k'] = v;
      });
    }
    final fv = j['formatVersion'], sv = j['schemaVersion'], sz = j['dbSize'];
    if (fv is! int ||
        sv is! int ||
        sz is! int ||
        j['dbSha256'] is! String ||
        j['app'] is! String) {
      throw BackupFormatException('متادیتای فایل پشتیبان ناقص است.');
    }
    return BackupMeta(
      formatVersion: fv,
      app: j['app'] as String,
      schemaVersion: sv,
      appVersion: '${j['appVersion'] ?? ''}',
      createdAt: '${j['createdAt'] ?? ''}',
      dbSha256: j['dbSha256'] as String,
      dbSize: sz,
      counts: counts,
    );
  }
}

class UnpackedBackup {
  final BackupMeta meta;
  final Uint8List db;
  const UnpackedBackup(this.meta, this.db);
}

/// فایل SQLite + اطلاعات ← بایت‌های فایل پشتیبان
Uint8List packBackup(
  Uint8List db, {
  required int schemaVersion,
  required String appVersion,
  required String createdAtIso,
  Map<String, int> counts = const {},
}) {
  final meta = BackupMeta(
    schemaVersion: schemaVersion,
    appVersion: appVersion,
    createdAt: createdAtIso,
    dbSha256: sha256Hex(db),
    dbSize: db.length,
    counts: counts,
  );
  final metaBytes = utf8.encode(jsonEncode(meta.toJson()));
  final out = BytesBuilder(copy: false);
  out.add(ascii.encode(kBackupMagic));
  final len = ByteData(4)..setUint32(0, metaBytes.length);
  out.add(len.buffer.asUint8List());
  out.add(metaBytes);
  out.add(db);
  return out.toBytes();
}

/// بررسی ساختار و سلامت (بدون باز کردن دیتابیس). در صورت هر مشکل BackupFormatException می‌دهد.
UnpackedBackup unpackBackup(Uint8List bytes, {int? maxSchemaVersion}) {
  const headLen = 12;
  if (bytes.length < headLen + 2) {
    throw BackupFormatException('فایل پشتیبان معتبر نیست (خیلی کوچک است).');
  }
  if (ascii.decode(bytes.sublist(0, 8), allowInvalid: true) != kBackupMagic) {
    throw BackupFormatException('این فایل، پشتیبان این نرم‌افزار نیست.');
  }
  final metaLen = ByteData.sublistView(bytes, 8, 12).getUint32(0);
  if (metaLen == 0 || metaLen > 64 * 1024 || headLen + metaLen > bytes.length) {
    throw BackupFormatException('ساختار فایل پشتیبان خراب است.');
  }
  final BackupMeta meta;
  try {
    final decoded = jsonDecode(
      utf8.decode(bytes.sublist(headLen, headLen + metaLen)),
    );
    if (decoded is! Map<String, dynamic>) throw const FormatException();
    meta = BackupMeta.fromJson(decoded);
  } on BackupFormatException {
    rethrow;
  } catch (_) {
    throw BackupFormatException('متادیتای فایل پشتیبان خوانده نشد.');
  }
  if (meta.app != kBackupApp) {
    throw BackupFormatException('این فایل، پشتیبان این نرم‌افزار نیست.');
  }
  if (meta.formatVersion > kBackupFormatVersion) {
    throw BackupFormatException(
      'این فایل با نسخه جدیدتری از نرم‌افزار ساخته شده است؛ برنامه را به‌روزرسانی کنید.',
    );
  }
  if (maxSchemaVersion != null && meta.schemaVersion > maxSchemaVersion) {
    throw BackupFormatException(
      'ساختار دیتابیس این پشتیبان از نسخه فعلی نرم‌افزار جدیدتر است؛ برنامه را به‌روزرسانی کنید.',
    );
  }
  final db = Uint8List.sublistView(bytes, headLen + metaLen);
  if (db.length != meta.dbSize) {
    throw BackupFormatException(
      'فایل پشتیبان ناقص یا خراب است (اندازه نامعتبر).',
    );
  }
  if (sha256Hex(db) != meta.dbSha256) {
    throw BackupFormatException('فایل پشتیبان خراب است (هش نامعتبر).');
  }
  // امضای SQLite
  if (db.length < 16 ||
      ascii.decode(db.sublist(0, 15), allowInvalid: true) !=
          'SQLite format 3') {
    throw BackupFormatException('محتوای دیتابیس داخل فایل معتبر نیست.');
  }
  return UnpackedBackup(meta, db);
}
