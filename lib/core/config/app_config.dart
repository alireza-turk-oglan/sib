import 'package:flutter/foundation.dart';

/// تنظیمات اتصال به پنل. مقادیر در زمان Build از فایل env/*.json تزریق می‌شوند:
///   flutter run -d windows --dart-define-from-file=env/dev.json
///
/// هشدار: هیچ کلید یا رمز محرمانه‌ای اینجا (یا در env) نگذارید.
/// هر چیزی داخل برنامه قابل استخراج است. کلیدهای IPPanel، مرچنت درگاه‌ها و
/// رمز دیتابیس فقط روی سرور هستند و برنامه هیچ‌کدام را نمی‌شناسد.
class AppConfig {
  AppConfig._();

  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'prod',
  );

  /// آدرس پایه API، مثلاً https://example.com/api/v1
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// آدرس سایت (برای لینک ثبت‌نام و خرید اشتراک)
  static const String siteUrl = String.fromEnvironment('SITE_URL');

  /// فقط برای توسعه؛ در نسخه نهایی هرگز پذیرفته نمی‌شود.
  static const bool allowInsecureHttp = bool.fromEnvironment(
    'ALLOW_INSECURE_HTTP',
  );

  static const int connectTimeoutSeconds = int.fromEnvironment(
    'API_CONNECT_TIMEOUT',
    defaultValue: 10,
  );
  static const int receiveTimeoutSeconds = int.fromEnvironment(
    'API_RECEIVE_TIMEOUT',
    defaultValue: 20,
  );

  static bool get isDev => environment == 'dev';

  /// آدرس کامل یک endpoint، مثلاً endpoint('auth/check')
  static Uri endpoint(String path) {
    final base = apiBaseUrl.endsWith('/')
        ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
        : apiBaseUrl;
    return Uri.parse('$base/$path');
  }

  /// آدرس کامل یک صفحه سایت، مثلاً sitePage('buy')
  static Uri sitePage(String path) {
    final base = siteUrl.endsWith('/')
        ? siteUrl.substring(0, siteUrl.length - 1)
        : siteUrl;
    return Uri.parse('$base/$path');
  }

  /// فهرست خطاهای پیکربندی؛ خالی یعنی معتبر. باید در main() قبل از runApp بررسی شود.
  static List<String> validate() => validateValues(
    apiBaseUrl: apiBaseUrl,
    siteUrl: siteUrl,
    allowInsecureHttp: allowInsecureHttp,
    isRelease: kReleaseMode,
  );

  /// جدا از validate() نوشته شده تا بدون dart-define قابل تست باشد.
  @visibleForTesting
  static List<String> validateValues({
    required String apiBaseUrl,
    required String siteUrl,
    required bool allowInsecureHttp,
    required bool isRelease,
  }) {
    final errors = <String>[];

    void checkUrl(String name, String value) {
      final uri = Uri.tryParse(value);
      if (value.isEmpty ||
          uri == null ||
          !uri.hasAuthority ||
          uri.host.isEmpty) {
        errors.add('$name تنظیم نشده یا نامعتبر است.');
        return;
      }
      if (uri.scheme == 'https') return;
      if (uri.scheme != 'http') {
        errors.add('$name باید با https شروع شود.');
      } else if (isRelease) {
        errors.add('$name در نسخه نهایی باید https باشد.');
      } else if (!allowInsecureHttp) {
        errors.add(
          'برای $name با http باید ALLOW_INSECURE_HTTP=true باشد (فقط توسعه).',
        );
      }
    }

    checkUrl('API_BASE_URL', apiBaseUrl);
    checkUrl('SITE_URL', siteUrl);
    if (isRelease && allowInsecureHttp) {
      errors.add('ALLOW_INSECURE_HTTP در نسخه نهایی مجاز نیست.');
    }
    return errors;
  }
}
