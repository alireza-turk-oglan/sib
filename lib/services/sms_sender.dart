import '../core/config/api_constants.dart';
import '../data/database.dart';
import '../data/repos/sms_repo.dart';
import 'api_models.dart';

enum SmsKind { info, promo, occasion }

extension SmsKindX on SmsKind {
  String get db => name;
  String get label => switch (this) {
    SmsKind.info => 'اطلاع‌رسانی',
    SmsKind.promo => 'تبلیغاتی',
    SmsKind.occasion => 'مناسبتی',
  };

  /// پیام تبلیغاتی و مناسبتی فقط برای مشتریانی که رضایت دریافت پیامک داده‌اند
  bool get needsConsent => this != SmsKind.info;
}

class SmsRecipient {
  final int? partyId;
  final String name;
  final String mobile;
  final bool consent;
  const SmsRecipient({
    this.partyId,
    required this.name,
    required this.mobile,
    required this.consent,
  });
}

class SmsOutcome {
  final int sent;
  final int failed;
  final int skippedNoConsent;
  final String batchId;
  final List<String> errors;
  final bool stoppedEarly;
  const SmsOutcome({
    required this.sent,
    required this.failed,
    required this.skippedNoConsent,
    required this.batchId,
    required this.errors,
    required this.stoppedEarly,
  });
}

/// پیام + گیرندگان → پاسخ API ({results:[{phone,status,error}]}) ؛ در تست می‌توان جایگزین کرد.
typedef SmsTransport =
    Future<Map<String, dynamic>> Function(
      String message,
      List<String> recipients,
    );

class SmsSender {
  final SmsTransport transport;
  final SmsRepo repo;
  SmsSender(this.transport, this.repo);

  static const int maxPerRequest = 500;
  static const int maxLength = 600;
  static const Set<String> _fatal = {
    ApiErrorCodes.dailyLimit,
    ApiErrorCodes.smsDisabled,
    ApiErrorCodes.subscriptionInactive,
    ApiErrorCodes.tokenInvalid,
    ApiErrorCodes.deviceMismatch,
    ApiErrorCodes.blocked,
  };

  static String personalize(String template, String name) => template
      .replaceAll('{name}', name.trim().isEmpty ? 'مشتری گرامی' : name.trim());

  static String? validate(String template) {
    final t = template.trim();
    if (t.length < 2) return 'متن پیامک را وارد کنید.';
    if (t.length > maxLength) {
      return 'متن پیامک بیش از $maxLength کاراکتر است.';
    }
    return null;
  }

  /// تعداد تقریبی بخش‌های پیامک (فارسی/یونیکد ۷۰ و ۶۷ ، لاتین ۱۶۰ و ۱۵۳). خود اپراتور مرجع نهایی است.
  static int parts(String text) {
    if (text.isEmpty) return 0;
    final unicode = text.runes.any((r) => r > 127);
    final single = unicode ? 70 : 160;
    final multi = unicode ? 67 : 153;
    return text.length <= single ? 1 : (text.length / multi).ceil();
  }

  Future<SmsOutcome> send({
    required List<SmsRecipient> recipients,
    required String template,
    required SmsKind kind,
    void Function(int done, int total)? onProgress,
  }) async {
    final err = validate(template);
    if (err != null) throw DomainError(err);
    final batch = '${DateTime.now().microsecondsSinceEpoch}';
    var skipped = 0;
    final seen = <String>{};
    final targets = <SmsRecipient>[];
    for (final r in recipients) {
      if (kind.needsConsent && !r.consent) {
        skipped++;
        continue;
      }
      if (seen.add(r.mobile)) targets.add(r);
    }
    if (targets.isEmpty) {
      throw DomainError(
        skipped > 0
            ? 'هیچ‌یک از گیرندگان انتخاب‌شده رضایت دریافت پیامک نداده‌اند.'
            : 'گیرنده‌ای انتخاب نشده است.',
      );
    }

    var sent = 0, failed = 0, done = 0;
    var stopped = false;
    final errors = <String>[];

    void log(SmsRecipient r, String message, bool ok, String? e) {
      repo.log(
        partyId: r.partyId,
        mobile: r.mobile,
        message: message,
        kind: kind.db,
        ok: ok,
        error: e,
        batchId: batch,
      );
      if (ok) {
        sent++;
      } else {
        failed++;
        if (e != null && !errors.contains(e) && errors.length < 5) {
          errors.add(e);
        }
      }
      done++;
      onProgress?.call(done, targets.length);
    }

    void failRest(List<SmsRecipient> rest, String message, String e) {
      for (final r in rest) {
        log(r, message, false, e);
      }
    }

    final personalized = template.contains('{name}');
    final groups = <List<SmsRecipient>>[];
    if (personalized) {
      for (final r in targets) {
        groups.add([r]);
      }
    } else {
      for (var i = 0; i < targets.length; i += maxPerRequest) {
        groups.add(
          targets.sublist(
            i,
            i + maxPerRequest > targets.length
                ? targets.length
                : i + maxPerRequest,
          ),
        );
      }
    }

    for (var gi = 0; gi < groups.length; gi++) {
      final g = groups[gi];
      final msg = personalized ? personalize(template, g.first.name) : template;
      try {
        final res = await transport(msg, [for (final r in g) r.mobile]);
        final byPhone = <String, Map<String, dynamic>>{};
        for (final x in (res['results'] as List? ?? const [])) {
          if (x is Map<String, dynamic>) byPhone['${x['phone']}'] = x;
        }
        for (final r in g) {
          final x = byPhone[r.mobile];
          final ok = x != null && x['status'] == 'sent';
          log(
            r,
            msg,
            ok,
            ok ? null : ((x?['error'] as String?) ?? 'نتیجه ارسال نامشخص'),
          );
        }
      } on ApiException catch (e) {
        failRest(g, msg, e.message);
        if (_fatal.contains(e.code)) {
          stopped = true;
          for (var k = gi + 1; k < groups.length; k++) {
            final m2 = personalized
                ? personalize(template, groups[k].first.name)
                : template;
            failRest(groups[k], m2, e.message);
          }
          break;
        }
      }
    }
    return SmsOutcome(
      sent: sent,
      failed: failed,
      skippedNoConsent: skipped,
      batchId: batch,
      errors: errors,
      stoppedEarly: stopped,
    );
  }
}
