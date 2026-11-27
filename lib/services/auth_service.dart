import '../core/config/api_constants.dart';
import 'api_client.dart';
import 'device_identity.dart';
import 'secure_store.dart';

class OtpTicket {
  final int ttlSeconds;
  final int resendAfterSeconds;
  const OtpTicket(this.ttlSeconds, this.resendAfterSeconds);
}

/// ورود با OTP و بررسی اشتراک. اعتبارسنجی نهایی همیشه سمت سرور است.
class AuthService {
  final ApiClient api;
  final SecureStore store;
  AuthService(this.api, this.store);

  Future<OtpTicket> requestOtp(String phone) async {
    final r = await api.post(ApiPaths.otpRequest, {'phone': phone, 'device_id': await DeviceIdentity.id()});
    return OtpTicket((r['ttl'] as num?)?.toInt() ?? OtpRules.ttlSeconds, (r['resend_after'] as num?)?.toInt() ?? 60);
  }

  /// موفق: توکن ذخیره می‌شود. ناموفق: ApiException (مثلاً subscription_inactive با اطلاعات اشتراک در body)
  Future<AuthResult> verifyOtp(String phone, String code) async {
    final r = await api.post(ApiPaths.otpVerify, {
      'phone': phone,
      'code': code,
      'device_id': await DeviceIdentity.id(),
      'device_name': DeviceIdentity.name(),
    });
    await store.saveSession('${r['token']}', phone);
    return AuthResult.fromJson(r, fallbackPhone: phone);
  }

  /// بررسی توکن ذخیره‌شده و اشتراک (هر بار اجرای برنامه). null یعنی توکنی ذخیره نشده.
  Future<AuthResult?> check() async {
    final token = await store.readToken();
    if (token == null || token.isEmpty) return null;
    final r = await api.post(ApiPaths.check, {'device_id': await DeviceIdentity.id()}, token: token);
    return AuthResult.fromJson(r, fallbackPhone: (await store.readPhone()) ?? '');
  }

  Future<void> logout() async {
    final token = await store.readToken();
    if (token != null) {
      try {
        await api.post(ApiPaths.logout, {'device_id': await DeviceIdentity.id()}, token: token);
      } catch (_) {
        // حتی بدون اینترنت، خروج محلی انجام می‌شود
      }
    }
    await store.clearToken();
  }

  /// ارسال پیامک باشگاه مشتریان از طریق سرور (کلید IPPanel فقط روی سرور است)
  Future<Map<String, dynamic>> sendSms(String message, List<String> recipients) async {
    final token = await store.readToken();
    if (token == null) throw ApiException(ApiErrorCodes.tokenInvalid, 'نشست شما منقضی شده است. دوباره وارد شوید.');
    return api.post(ApiPaths.smsSend, {'device_id': await DeviceIdentity.id(), 'message': message, 'recipients': recipients}, token: token);
  }
}
