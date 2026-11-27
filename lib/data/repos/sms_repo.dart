import '../../core/utils/format.dart';
import '../database.dart';
import '../models.dart';
import '../queries.dart';

/// تاریخچه پیامک‌های ارسالی باشگاه مشتریان (نتیجه هر گیرنده)
class SmsRepo {
  final AppDatabase db;
  SmsRepo(this.db);

  void log({
    int? partyId,
    required String mobile,
    required String message,
    required String kind,
    required bool ok,
    String? error,
    required String batchId,
  }) {
    db.exec(
      'INSERT INTO sms_log(party_id, mobile, message, kind, status, error, batch_id, created_at) VALUES(?,?,?,?,?,?,?,?)',
      [
        partyId,
        mobile,
        message,
        kind,
        ok ? 'sent' : 'failed',
        ok ? null : error,
        batchId,
        nowIsoUtc(),
      ],
    );
  }

  List<SmsLogRow> history({int limit = 300}) =>
      db.query(qSmsHistory, [limit]).map(SmsLogRow.fromRow).toList();

  int failedCount(String batchId) => db.intScalar(
    "SELECT COUNT(*) FROM sms_log WHERE batch_id=? AND status='failed'",
    [batchId],
  );

  /// شناسه طرف‌حساب‌هایی که در یک دسته ارسال ناموفق بوده‌اند (برای «تلاش مجدد»)
  List<int> failedPartyIds(String batchId) => db
      .query(
        "SELECT DISTINCT party_id FROM sms_log WHERE batch_id=? AND status='failed' AND party_id IS NOT NULL",
        [batchId],
      )
      .map((r) => r['party_id'] as int)
      .toList();
}
