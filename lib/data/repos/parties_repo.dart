import '../../core/utils/format.dart';
import '../database.dart';
import '../models.dart';
import '../queries.dart';

/// مشتریان و تأمین‌کنندگان (طرف‌حساب‌ها)
class PartiesRepo {
  final AppDatabase db;
  PartiesRepo(this.db);

  static const _prefix = {'customer': 'C', 'supplier': 'V'};

  List<Party> list(String kind, {String query = ''}) {
    final q = normalizeFa(enDigits(query));
    return db
        .query(qPartiesWithBalance, [kind, q, q, q, q])
        .map(Party.fromRow)
        .toList();
  }

  Party? get(int id) {
    final r = db.one('SELECT * FROM parties WHERE id = ?', [id]);
    if (r == null) return null;
    final all = db.query(qPartiesWithBalance, [r['kind'], '', '', '', '']);
    for (final x in all) {
      if (x['id'] == id) return Party.fromRow(x);
    }
    return Party.fromRow(r);
  }

  String nextCode(String kind) {
    final p = _prefix[kind]!;
    final n = db.intScalar(
      "SELECT COALESCE(MAX(CAST(SUBSTR(code, 2) AS INTEGER)), 0) + 1 FROM parties WHERE kind = ? AND code LIKE '$p%'",
      [kind],
    );
    return '$p${n.toString().padLeft(4, '0')}';
  }

  String? _validate({
    required String name,
    String? mobileInput,
    required String description,
  }) {
    if (name.isEmpty) return 'نام را وارد کنید.';
    if (name.length > 100) return 'نام بیش از حد طولانی است.';
    if (description.length > 500) return 'توضیحات بیش از حد طولانی است.';
    if (mobileInput != null &&
        mobileInput.trim().isNotEmpty &&
        normalizeMobile(mobileInput) == null) {
      return 'شماره موبایل معتبر نیست (فرمت صحیح: 09xxxxxxxxx).';
    }
    return null;
  }

  int create({
    required String kind,
    required String name,
    String? mobile,
    String description = '',
    bool smsConsent = false,
    String? code,
  }) {
    final n = normalizeFa(name);
    final err = _validate(
      name: n,
      mobileInput: mobile,
      description: description,
    );
    if (err != null) throw DomainError(err);
    final m = (mobile == null || mobile.trim().isEmpty)
        ? null
        : normalizeMobile(mobile);
    return db.transaction(() {
      final c = (code == null || code.trim().isEmpty)
          ? nextCode(kind)
          : code.trim();
      db.exec(
        'INSERT INTO parties(code, kind, name, mobile, description, sms_consent, created_at) VALUES(?,?,?,?,?,?,?)',
        [
          c,
          kind,
          n,
          m,
          description.trim().isEmpty ? null : description.trim(),
          smsConsent ? 1 : 0,
          nowIsoUtc(),
        ],
      );
      return db.lastInsertId;
    });
  }

  void update(
    int id, {
    required String name,
    String? mobile,
    String description = '',
    required bool smsConsent,
    required bool isActive,
  }) {
    final n = normalizeFa(name);
    final err = _validate(
      name: n,
      mobileInput: mobile,
      description: description,
    );
    if (err != null) throw DomainError(err);
    final m = (mobile == null || mobile.trim().isEmpty)
        ? null
        : normalizeMobile(mobile);
    final changed = db.exec(
      'UPDATE parties SET name=?, mobile=?, description=?, sms_consent=?, is_active=? WHERE id=? AND deleted_at IS NULL',
      [
        n,
        m,
        description.trim().isEmpty ? null : description.trim(),
        smsConsent ? 1 : 0,
        isActive ? 1 : 0,
        id,
      ],
    );
    if (changed == 0) throw DomainError('مورد پیدا نشد.');
  }

  /// حذف منطقی؛ فقط وقتی مانده‌ای ندارد. سوابق فاکتور و پرداخت دست‌نخورده می‌مانند.
  void delete(int id) {
    final p = get(id);
    if (p == null) throw DomainError('مورد پیدا نشد.');
    if (p.balance != 0) {
      throw DomainError(
        'این طرف‌حساب مانده حساب دارد؛ ابتدا تسویه کنید یا آن را غیرفعال کنید.',
      );
    }
    db.exec('UPDATE parties SET deleted_at=?, mobile=NULL WHERE id=?', [
      nowIsoUtc(),
      id,
    ]);
  }

  int count(String kind) => db.intScalar(
    'SELECT COUNT(*) FROM parties WHERE kind=? AND deleted_at IS NULL',
    [kind],
  );

  /// ردیف‌های فاکتور یک طرف‌حساب برای «تاریخچه خرید» و «خدمات دریافت‌شده». kinds: کالا → ('product','product') ، خدمات → ('service','free')
  List<Map<String, Object?>> linesOf(
    int partyId, {
    required bool products,
    int limit = 300,
  }) => db.query(
    '''SELECT i.id AS invoice_id, i.date AS date, i.number AS number, ii.title AS title, ii.qty_milli AS qty_milli,
                ii.unit_price AS unit_price, ii.discount AS discount, ii.line_total AS line_total
         FROM invoice_items ii JOIN invoices i ON i.id = ii.invoice_id
         WHERE i.party_id = ? AND i.kind = 'sale' AND i.deleted_at IS NULL AND ii.item_kind IN (?, ?)
         ORDER BY i.date DESC, i.number DESC, ii.id LIMIT ?''',
    [
      partyId,
      ...(products ? ['product', 'product'] : ['service', 'free']),
      limit,
    ],
  );
}
