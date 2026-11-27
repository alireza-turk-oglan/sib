import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/api_constants.dart';
import '../core/config/app_config.dart';
import '../core/platform/app_log.dart';
import 'api_models.dart';

export 'api_models.dart';

/// تنها نقطه ارتباط شبکه‌ای برنامه. فقط داده‌های احراز هویت/اشتراک/پیامک عبور می‌کنند؛ داده‌های حسابداری هرگز.
class ApiClient {
  final http.Client _client;
  ApiClient([http.Client? client]) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, Object?> body, {
    String? token,
  }) async {
    final uri = AppConfig.endpoint(path);
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      if (token != null) ApiHeaders.authorization: ApiHeaders.bearer(token),
    };
    final http.Response res;
    try {
      res = await _client
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(
            Duration(
              seconds:
                  AppConfig.connectTimeoutSeconds +
                  AppConfig.receiveTimeoutSeconds,
            ),
          );
    } on TimeoutException {
      throw ApiException(
        'timeout',
        'پاسخی از سرور دریافت نشد. اتصال اینترنت را بررسی کنید.',
      );
    } catch (e) {
      Log.error('api network error on $path', e);
      throw ApiException(
        'network',
        'اتصال به سرور برقرار نشد. اتصال اینترنت را بررسی کنید.',
      );
    }
    Map<String, dynamic>? j;
    try {
      final d = jsonDecode(utf8.decode(res.bodyBytes));
      if (d is Map<String, dynamic>) j = d;
    } catch (_) {}
    if (j == null) {
      throw ApiException(
        'bad_response',
        'پاسخ نامعتبر از سرور دریافت شد.',
        status: res.statusCode,
      );
    }
    if (res.statusCode >= 200 && res.statusCode < 300 && j['ok'] == true) {
      return j;
    }
    throw ApiException(
      '${j['code'] ?? 'error'}',
      '${j['message'] ?? 'خطای ناشناخته'}',
      status: res.statusCode,
      body: j,
    );
  }

  void close() => _client.close();
}
