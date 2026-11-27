import '../core/config/api_constants.dart';

/// خطای ارتباط با پنل. code: کد خطای سرور یا 'network' / 'timeout' / 'bad_response'
class ApiException implements Exception {
  final String code;
  final String message;
  final int? status;
  final Map<String, dynamic>? body;
  ApiException(this.code, this.message, {this.status, this.body});
  bool get isNetwork => code == 'network' || code == 'timeout' || code == 'bad_response' || code == ApiErrorCodes.serverError;
  @override
  String toString() => message;
}

class SubscriptionInfo {
  final String status; // active | expired | none | suspended | blocked
  final String? type; // trial | free | paid
  final DateTime? endsAt;
  final int daysLeft;
  const SubscriptionInfo({required this.status, this.type, this.endsAt, this.daysLeft = 0});
  bool get isActive => status == 'active';
  String get typeLabel => switch (type) { 'trial' => 'آزمایشی', 'free' => 'رایگان', 'paid' => 'خریداری‌شده', _ => '—' };

  factory SubscriptionInfo.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const SubscriptionInfo(status: 'none');
    return SubscriptionInfo(
      status: '${j['status'] ?? 'none'}',
      type: j['type'] as String?,
      endsAt: j['ends_at'] is String ? DateTime.tryParse(j['ends_at'] as String)?.toLocal() : null,
      daysLeft: (j['days_left'] as num?)?.toInt() ?? 0,
    );
  }
}

class AppInfo {
  final String latestVersion;
  final String minVersion;
  final String downloadUrl;
  const AppInfo({this.latestVersion = '', this.minVersion = '', this.downloadUrl = ''});
  factory AppInfo.fromJson(Map<String, dynamic>? j) =>
      AppInfo(latestVersion: '${j?['latest_version'] ?? ''}', minVersion: '${j?['min_version'] ?? ''}', downloadUrl: '${j?['download_url'] ?? ''}');
}

/// نتیجه ورود/بررسی اشتراک. name = نام و نام خانوادگی ثبت‌شده در سایت (ممکن است خالی باشد).
class AuthResult {
  final String phone;
  final String name;
  final SubscriptionInfo subscription;
  final AppInfo app;
  const AuthResult(this.phone, this.subscription, this.app, {this.name = ''});

  factory AuthResult.fromJson(Map<String, dynamic> r, {String fallbackPhone = ''}) {
    final u = r['user'] is Map ? r['user'] as Map : const {};
    return AuthResult(
      '${u['phone'] ?? fallbackPhone}',
      SubscriptionInfo.fromJson(r['subscription'] as Map<String, dynamic>?),
      AppInfo.fromJson(r['app'] as Map<String, dynamic>?),
      name: '${u['name'] ?? ''}'.trim(),
    );
  }
}
