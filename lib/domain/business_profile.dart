import 'dart:convert';
import 'dart:typed_data';

import '../data/repos/settings_repo.dart';

/// نام و لوگوی اختیاری کسب‌وکار. لوگو (PNG کوچک‌شده) به‌صورت base64 داخل تنظیمات دیتابیس ذخیره می‌شود
/// تا همراه پشتیبان‌گیری/بازیابی منتقل شود.
class BusinessProfile {
  static const nameKey = 'business_name';
  static const logoKey = 'business_logo';
  static const maxLogoBytes = 300 * 1024;

  final String name;
  final Uint8List? logo;
  const BusinessProfile({this.name = '', this.logo});
  const BusinessProfile.empty() : this();

  bool get hasLogo => logo != null;
  String get displayName => name.trim();

  factory BusinessProfile.fromSettings(SettingsRepo s) =>
      BusinessProfile(name: s.get(nameKey).trim(), logo: decodeLogo(s.get(logoKey)));

  /// مقدار نامعتبر/خالی/بیش‌ازحد بزرگ ← null (لوگو نادیده گرفته می‌شود، برنامه خراب نمی‌شود)
  static Uint8List? decodeLogo(String b64) {
    if (b64.isEmpty) return null;
    try {
      final b = base64Decode(b64);
      if (b.isEmpty || b.length > maxLogoBytes) return null;
      return b;
    } catch (_) {
      return null;
    }
  }

  static String encodeLogo(Uint8List bytes) => base64Encode(bytes);
}
