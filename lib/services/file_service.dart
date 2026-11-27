import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

/// دسترسی به دیالوگ‌های فایل و باز کردن لینک/فایل. همه توابع بدون استثنا برمی‌گردند (null = لغو/ناموفق).
///
/// سازگار با API جدید file_picker (نسخه ۱۲ به بعد): متدها استاتیک‌اند (بدون FilePicker.platform)،
/// pickFiles مستقیم لیست فایل‌ها (خالی = لغو) و saveFile مقدار Uri برمی‌گرداند و خودش bytes را می‌نویسد.
/// نتیجه‌ها عمداً به‌صورت dynamic پردازش می‌شوند تا با شکل قدیمی خروجی (FilePickerResult / String) هم کار کند.
class FileService {
  static String? _firstPath(dynamic r) {
    if (r == null) return null;
    final Iterable files = r is Iterable ? r : (r.files as Iterable);
    if (files.isEmpty) return null;
    return files.first.path as String?;
  }

  static Future<String?> pickDirectory(String title) async {
    try {
      return await FilePicker.getDirectoryPath(dialogTitle: title);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> pickBackupFile() async {
    try {
      final dynamic r = await FilePicker.pickFiles(dialogTitle: 'انتخاب فایل پشتیبان', type: FileType.custom, allowedExtensions: const ['sibbak']);
      return _firstPath(r);
    } catch (_) {
      return null;
    }
  }

  /// انتخاب تصویر (برای لوگو). مسیر فایل یا null.
  static Future<String?> pickImage() async {
    try {
      final dynamic r = await FilePicker.pickFiles(
        dialogTitle: 'انتخاب لوگو',
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif'],
      );
      return _firstPath(r);
    } catch (_) {
      return null;
    }
  }

  /// نمایش دیالوگ ذخیره (که خودش فایل را می‌نویسد) و اطمینان از پسوند. مسیر نهایی یا null.
  static Future<String?> saveBytes({required String title, required String fileName, required String ext, required Uint8List bytes}) async {
    try {
      final dynamic res = await FilePicker.saveFile(dialogTitle: title, fileName: fileName, bytes: bytes);
      if (res == null) return null;
      var path = res is Uri ? res.toFilePath() : res.toString();
      if (!path.toLowerCase().endsWith('.$ext')) path = '$path.$ext';
      await File(path).writeAsBytes(bytes, flush: true);
      return path;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> openUrl(String url) async {
    try {
      final u = Uri.tryParse(url);
      if (u == null || !(u.scheme == 'http' || u.scheme == 'https')) return false;
      return await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// باز کردن فایل یا پوشه با برنامه پیش‌فرض سیستم
  static Future<bool> openPath(String path) async {
    try {
      return await launchUrl(Uri.file(path));
    } catch (_) {
      return false;
    }
  }

  /// فایل موقت برای نمایش/چاپ (مثلاً PDF)
  static Future<String> writeTemp(String name, Uint8List bytes) async {
    final dir = Directory('${Directory.systemTemp.path}${Platform.pathSeparator}sib-temp')..createSync(recursive: true);
    final p = '${dir.path}${Platform.pathSeparator}$name';
    await File(p).writeAsBytes(bytes, flush: true);
    return p;
  }
}
