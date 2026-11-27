import 'dart:convert';
import 'dart:io';

/// تنظیمات ظاهری/محلی برنامه (قبل از ورود هم لازم‌اند، پس داخل دیتابیس نیستند): تم، پوشه پشتیبان، پشتیبان خودکار.
class PrefsStore {
  final String path;
  final Map<String, Object?> _m;
  PrefsStore._(this.path, this._m);

  static PrefsStore load(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) {
        final d = jsonDecode(f.readAsStringSync());
        if (d is Map<String, dynamic>) {
          return PrefsStore._(path, Map<String, Object?>.from(d));
        }
      }
    } catch (_) {}
    return PrefsStore._(path, {});
  }

  String? getString(String k) => _m[k] is String ? _m[k] as String : null;
  bool getBool(String k, bool def) => _m[k] is bool ? _m[k] as bool : def;

  void setString(String k, String? v) {
    if (v == null) {
      _m.remove(k);
    } else {
      _m[k] = v;
    }
    _save();
  }

  void setBool(String k, bool v) {
    _m[k] = v;
    _save();
  }

  void _save() {
    try {
      final tmp = File('$path.tmp');
      tmp.writeAsStringSync(jsonEncode(_m), flush: true);
      tmp.renameSync(path);
    } catch (_) {}
  }
}
