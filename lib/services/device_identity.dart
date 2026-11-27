import 'dart:io';
import 'dart:math';

import '../core/utils/sha256.dart';
import '../core/platform/app_paths.dart';

/// شناسه پایدار این کامپیوتر برای قفل «یک اشتراک = یک دستگاه».
/// از MachineGuid ویندوز ساخته و هش می‌شود (خود GUID به سرور فرستاده نمی‌شود).
class DeviceIdentity {
  static String? _id;

  static Future<String> id() async {
    if (_id != null) return _id!;
    String? guid;
    if (Platform.isWindows) {
      try {
        final r = await Process.run('reg', ['query', r'HKLM\SOFTWARE\Microsoft\Cryptography', '/v', 'MachineGuid']);
        final m = RegExp(r'MachineGuid\s+REG_SZ\s+([0-9A-Fa-f\-]{16,})').firstMatch('${r.stdout}');
        guid = m?.group(1);
      } catch (_) {}
    }
    guid ??= _fallbackGuid();
    _id = 'W${sha256Hex('sib-device-v1|$guid'.codeUnits).substring(0, 39)}';
    return _id!;
  }

  /// اگر خواندن MachineGuid ممکن نبود، یک شناسه تصادفی کنار داده‌ها ذخیره می‌شود.
  static String _fallbackGuid() {
    final f = File('${AppPaths.dataDir}${Platform.pathSeparator}.device');
    try {
      if (f.existsSync()) return f.readAsStringSync().trim();
      final r = Random.secure();
      final v = List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
      f.writeAsStringSync(v);
      return v;
    } catch (_) {
      return 'unknown-device';
    }
  }

  static String name() {
    try {
      return Platform.localHostname;
    } catch (_) {
      return 'Windows';
    }
  }
}
