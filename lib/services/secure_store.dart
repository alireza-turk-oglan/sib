import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/platform/app_log.dart';

/// نگهداری توکن ورود در ذخیره‌ساز امن سیستم‌عامل. اگر در دسترس نبود، برنامه کار می‌کند ولی هر بار باید دوباره وارد شد.
class SecureStore {
  static const _s = FlutterSecureStorage();
  static const _kToken = 'api_token';
  static const _kPhone = 'phone';

  Future<String?> readToken() => _read(_kToken);
  Future<String?> readPhone() => _read(_kPhone);

  Future<void> saveSession(String token, String phone) async {
    try {
      await _s.write(key: _kToken, value: token);
      await _s.write(key: _kPhone, value: phone);
    } catch (e) {
      Log.error('secure storage write failed', e);
    }
  }

  Future<void> clearToken() async {
    try {
      await _s.delete(key: _kToken);
    } catch (e) {
      Log.error('secure storage delete failed', e);
    }
  }

  Future<String?> _read(String key) async {
    try {
      return await _s.read(key: key);
    } catch (e) {
      Log.error('secure storage read failed', e);
      return null;
    }
  }
}
