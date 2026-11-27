import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// مسیرهای ذخیره‌سازی. اطلاعات کاربر جدا از فایل‌های برنامه و در پوشه قابل‌نوشتن کاربر نگهداری می‌شود
/// (Windows: %APPDATA%\...\data) و با حذف/به‌روزرسانی برنامه از بین نمی‌رود.
class AppPaths {
  AppPaths._();
  static late String dataDir;
  static late String dbPath;
  static late String logsDir;
  static late String autoBackupDir;
  static late String safetyDir;
  static late String prefsPath;
  static late String defaultBackupDir;
  static const sep = '/';

  static Future<void> init() async {
    final support = await getApplicationSupportDirectory();
    final docs = await getApplicationDocumentsDirectory();
    String j(String a, String b) => '$a${Platform.pathSeparator}$b';
    dataDir = j(support.path, 'data');
    dbPath = j(dataDir, 'accounting.db');
    logsDir = j(support.path, 'logs');
    autoBackupDir = j(support.path, 'auto-backups');
    safetyDir = j(support.path, 'safety-backups');
    prefsPath = j(support.path, 'prefs.json');
    defaultBackupDir = j(docs.path, 'Accounting Backups');
    for (final d in [dataDir, logsDir, autoBackupDir, safetyDir]) {
      Directory(d).createSync(recursive: true);
    }
  }
}
