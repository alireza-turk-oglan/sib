import '../../core/utils/format.dart';
import '../../core/utils/jalali.dart';
import '../database.dart';
import '../models.dart';
import '../queries.dart';

/// دریافت و پرداخت وجه: کامل/جزئی، چندبخشی برای یک فاکتور، و پرداخت عمومی (بستانکاری)
class PaymentsRepo {
  final AppDatabase db;
  PaymentsRepo(this.db);

  List<PaymentRow> of({int? partyId, int? invoiceId, int limit = 200}) => db
      .query(qPaymentsOf, [partyId, partyId, invoiceId, invoiceId, limit])
      .map(PaymentRow.fromRow)
      .toList();

  /// پرداخت برای یک فاکتور (invoiceId) یا پرداخت عمومی طرف‌حساب (فقط partyId).
  int add({
    int? invoiceId,
    int? partyId,
    required String method,
    required int amount,
    required String date,
    String description = '',
  }) {
    if (!kMethodLabels.containsKey(method)) {
      throw DomainError('روش پرداخت نامعتبر است.');
    }
    if (amount <= 0) throw DomainError('مبلغ باید بیشتر از صفر باشد.');
    if (amount > 1000000000000) throw DomainError('مبلغ بیش از حد مجاز است.');
    if (parseIso(date) == null) throw DomainError('تاریخ نامعتبر است.');
    if (description.length > 300) {
      throw DomainError('توضیحات بیش از حد طولانی است.');
    }
    return db.transaction(() {
      final String direction;
      int? party = partyId;
      if (invoiceId != null) {
        final inv = db.one(
          '''SELECT i.kind, i.party_id, i.total,
            COALESCE((SELECT SUM(y.amount) FROM payments y WHERE y.invoice_id = i.id AND y.deleted_at IS NULL), 0) AS paid
            FROM invoices i WHERE i.id=? AND i.deleted_at IS NULL''',
          [invoiceId],
        );
        if (inv == null) throw DomainError('فاکتور پیدا نشد.');
        direction = inv['kind'] == 'sale' ? 'in' : 'out';
        party = inv['party_id'] as int?;
        final remaining = (inv['total'] as int) - (inv['paid'] as int);
        if (amount > remaining) {
          throw DomainError(
            'مبلغ از مانده فاکتور (${fmtToman(remaining)}) بیشتر است. برای مبلغ اضافه، «پرداخت عمومی» ثبت کنید.',
          );
        }
      } else {
        if (party == null) throw DomainError('طرف‌حساب را انتخاب کنید.');
        final p = db.one(
          'SELECT kind FROM parties WHERE id=? AND deleted_at IS NULL',
          [party],
        );
        if (p == null) throw DomainError('طرف‌حساب پیدا نشد.');
        direction = p['kind'] == 'customer' ? 'in' : 'out';
      }
      db.exec(
        'INSERT INTO payments(party_id, invoice_id, direction, method, amount, date, description, created_at) VALUES(?,?,?,?,?,?,?,?)',
        [
          party,
          invoiceId,
          direction,
          method,
          amount,
          date,
          description.trim().isEmpty ? null : description.trim(),
          nowIsoUtc(),
        ],
      );
      return db.lastInsertId;
    });
  }

  void delete(int id) {
    final c = db.exec(
      'UPDATE payments SET deleted_at=? WHERE id=? AND deleted_at IS NULL',
      [nowIsoUtc(), id],
    );
    if (c == 0) throw DomainError('پرداخت پیدا نشد.');
  }

  /// اختصاص پرداخت عمومی (بستانکاری) به یک فاکتور هم‌نوع و هم‌طرف‌حساب
  void allocate(int paymentId, int invoiceId) {
    db.transaction(() {
      final p = db.one(
        'SELECT party_id, invoice_id, direction FROM payments WHERE id=? AND deleted_at IS NULL',
        [paymentId],
      );
      if (p == null) throw DomainError('پرداخت پیدا نشد.');
      if (p['invoice_id'] != null) {
        throw DomainError('این پرداخت قبلاً به فاکتور اختصاص یافته است.');
      }
      db.exec('UPDATE payments SET invoice_id=? WHERE id=?', [
        invoiceId,
        paymentId,
      ]);
    });
  }

  void unallocate(int paymentId) {
    final p = db.one(
      'SELECT party_id, invoice_id FROM payments WHERE id=? AND deleted_at IS NULL',
      [paymentId],
    );
    if (p == null) throw DomainError('پرداخت پیدا نشد.');
    if (p['party_id'] == null) {
      throw DomainError(
        'پرداخت فاکتورِ بدون طرف‌حساب را نمی‌توان از فاکتور جدا کرد.',
      );
    }
    db.exec('UPDATE payments SET invoice_id=NULL WHERE id=?', [paymentId]);
  }

  /// فهرست کامل پرداخت‌ها با نام طرف‌حساب (برای صفحه پرداخت‌ها). method/direction: خالی = همه
  List<Map<String, Object?>> listDetailed({
    required String from,
    required String to,
    int? partyId,
    String method = '',
    String direction = '',
    int limit = 1000,
  }) => db.query(qPaymentsReport, [
    from,
    to,
    partyId,
    partyId,
    method,
    method,
    direction,
    direction,
    limit,
  ]);

  /// فاکتورهای باز یک طرف‌حساب برای اختصاص پرداخت: [{id, number, date, total, paid}]
  List<Map<String, Object?>> openInvoicesOf(int partyId, String kind) =>
      db.query(
        '''SELECT * FROM (
           SELECT i.id AS id, i.number AS number, i.date AS date, i.total AS total,
             COALESCE((SELECT SUM(y.amount) FROM payments y WHERE y.invoice_id = i.id AND y.deleted_at IS NULL), 0) AS paid
           FROM invoices i WHERE i.party_id = ? AND i.kind = ? AND i.deleted_at IS NULL
         ) WHERE paid < total ORDER BY date, number''',
        [partyId, kind],
      );
}
