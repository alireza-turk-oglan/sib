import '../../core/utils/format.dart';
import '../../core/utils/jalali.dart';
import '../../domain/invoice_calc.dart';
import '../database.dart';
import '../models.dart';
import '../queries.dart';
import 'settings_repo.dart';

const String _qInvoiceById = r'''
SELECT i.id, i.kind, i.number, i.date, i.total, i.party_id, COALESCE(p.name, i.party_name, '') AS party_name, i.description,
  COALESCE((SELECT SUM(y.amount) FROM payments y WHERE y.invoice_id = i.id AND y.deleted_at IS NULL), 0) AS paid
FROM invoices i LEFT JOIN parties p ON p.id = i.party_id
WHERE i.id = ? AND i.deleted_at IS NULL''';

/// فاکتور فروش/خدمات و فاکتور خرید/هزینه
class InvoicesRepo {
  final AppDatabase db;
  final SettingsRepo settings;
  InvoicesRepo(this.db, this.settings);

  int nextNumber(String kind) => db.intScalar(
    'SELECT COALESCE(MAX(number), 0) + 1 FROM invoices WHERE kind=?',
    [kind],
  );

  List<InvoiceSummary> list({
    required String kind,
    String from = '0000-01-01',
    String to = '9999-12-31',
    int? partyId,
    int? number,
    String status = 'all',
    int limit = 500,
    int offset = 0,
  }) => db
      .query(qInvoiceList, [
        kind,
        from,
        to,
        partyId,
        partyId,
        number,
        number,
        status,
        status,
        status,
        status,
        status,
        limit,
        offset,
      ])
      .map(InvoiceSummary.fromRow)
      .toList();

  InvoiceDetail? get(int id) {
    final r = db.one(_qInvoiceById, [id]);
    if (r == null) return null;
    final lines = db
        .query(qInvoiceItems, [id])
        .map(InvoiceLine.fromRow)
        .toList();
    final pays = db
        .query(qPaymentsOf, [null, null, id, id, 200])
        .map(PaymentRow.fromRow)
        .toList();
    return InvoiceDetail(InvoiceSummary.fromRow(r), lines, pays);
  }

  int save(InvoiceDraft d) {
    if (d.kind != 'sale' && d.kind != 'purchase') {
      throw DomainError('نوع فاکتور نامعتبر است.');
    }
    if (parseIso(d.date) == null) {
      throw DomainError('تاریخ فاکتور نامعتبر است.');
    }
    if (d.lines.isEmpty) {
      throw DomainError('فاکتور باید حداقل یک ردیف داشته باشد.');
    }
    if (d.lines.length > 200) {
      throw DomainError('تعداد ردیف‌ها بیش از حد مجاز است.');
    }
    if (d.description.length > 500) {
      throw DomainError('توضیحات بیش از حد طولانی است.');
    }
    for (var i = 0; i < d.lines.length; i++) {
      final l = d.lines[i];
      final err = validateLine(
        title: l.title,
        qty: l.qty,
        unitPrice: l.unitPrice,
        discount: l.discount,
      );
      if (err != null) throw DomainError('ردیف ${faDigits(i + 1)}: $err');
    }
    final isSale = d.kind == 'sale';

    return db.transaction(() {
      // طرف‌حساب
      String? partyName = d.partyName == null || d.partyName!.trim().isEmpty
          ? null
          : normalizeFa(d.partyName!);
      if (d.partyId != null) {
        final p = db.one(
          'SELECT name, kind, is_active FROM parties WHERE id=? AND deleted_at IS NULL',
          [d.partyId],
        );
        if (p == null) throw DomainError('طرف‌حساب پیدا نشد.');
        if (p['kind'] != (isSale ? 'customer' : 'supplier')) {
          throw DomainError('نوع طرف‌حساب با نوع فاکتور هم‌خوان نیست.');
        }
        partyName = p['name'] as String;
      }

      // کالا/خدمت‌ها
      final items = <int, DbRow>{};
      for (final l in d.lines) {
        final iid = l.itemId;
        if (iid == null || items.containsKey(iid)) continue;
        final it = db.one(
          'SELECT id, kind, name, purchase_price, track_stock, is_active, deleted_at FROM items WHERE id=?',
          [iid],
        );
        if (it == null || it['deleted_at'] != null) {
          throw DomainError('«${l.title}» پیدا نشد یا حذف شده است.');
        }
        items[iid] = it;
      }

      final now = nowIsoUtc();
      final int id;
      final isNew = d.id == null;
      var paid = 0;
      final affected = <int>{};
      final total = sumLines(d.lines);

      if (isNew) {
        final number = nextNumber(d.kind);
        db.exec(
          'INSERT INTO invoices(kind, number, party_id, party_name, date, description, total, created_at, updated_at) VALUES(?,?,?,?,?,?,?,?,?)',
          [
            d.kind,
            number,
            d.partyId,
            partyName,
            d.date,
            d.description.trim().isEmpty ? null : d.description.trim(),
            total,
            now,
            now,
          ],
        );
        id = db.lastInsertId;
      } else {
        id = d.id!;
        final ex = db.one(
          'SELECT kind FROM invoices WHERE id=? AND deleted_at IS NULL',
          [id],
        );
        if (ex == null) throw DomainError('فاکتور پیدا نشد یا حذف شده است.');
        if (ex['kind'] != d.kind) {
          throw DomainError('نوع فاکتور قابل تغییر نیست.');
        }
        paid = db.intScalar(
          'SELECT COALESCE(SUM(amount),0) FROM payments WHERE invoice_id=? AND deleted_at IS NULL',
          [id],
        );
        if (total < paid) {
          throw DomainError(
            'مبلغ جدید فاکتور (${fmtToman(total)}) کمتر از مجموع پرداخت‌های ثبت‌شده (${fmtToman(paid)}) است.',
          );
        }
        if (paid > 0 &&
            d.partyId !=
                db.one('SELECT party_id FROM invoices WHERE id=?', [
                  id,
                ])!['party_id']) {
          throw DomainError(
            'فاکتور دارای پرداخت است؛ طرف‌حساب آن قابل تغییر نیست.',
          );
        }
        for (final r in db.query(
          'SELECT DISTINCT item_id FROM invoice_items WHERE invoice_id=? AND item_id IS NOT NULL',
          [id],
        )) {
          affected.add(r['item_id'] as int);
        }
        db.exec('DELETE FROM invoice_items WHERE invoice_id=?', [id]);
        db.exec('DELETE FROM stock_movements WHERE ref_invoice_id=?', [id]);
        db.exec(
          'UPDATE invoices SET party_id=?, party_name=?, date=?, description=?, total=?, updated_at=? WHERE id=?',
          [
            d.partyId,
            partyName,
            d.date,
            d.description.trim().isEmpty ? null : d.description.trim(),
            total,
            now,
            id,
          ],
        );
      }

      var sort = 0;
      for (final l in d.lines) {
        final it = l.itemId == null ? null : items[l.itemId!];
        final kind = it == null ? 'free' : it['kind'] as String;
        final cost = (isSale && it != null) ? it['purchase_price'] as int : 0;
        db.exec(
          'INSERT INTO invoice_items(invoice_id, item_id, title, item_kind, qty_milli, unit_price, discount, line_total, cost_unit, sort) VALUES(?,?,?,?,?,?,?,?,?,?)',
          [
            id,
            l.itemId,
            normalizeFa(l.title),
            kind,
            qtyMilli(l.qty),
            l.unitPrice,
            l.discount,
            l.total,
            cost,
            sort++,
          ],
        );
        if (it != null && kind == 'product' && it['track_stock'] == 1) {
          affected.add(l.itemId!);
          db.exec(
            'INSERT INTO stock_movements(item_id, qty_milli, reason, ref_invoice_id, date, created_at) VALUES(?,?,?,?,?,?)',
            [
              l.itemId,
              (isSale ? -1 : 1) * qtyMilli(l.qty),
              isSale ? 'sale' : 'purchase',
              id,
              d.date,
              now,
            ],
          );
        }
      }
      _assertStockOk(affected);

      // آخرین قیمت خرید (فقط برای فاکتور خرید جدید)
      if (!isSale && isNew && settings.updateCostOnPurchase) {
        for (final l in d.lines) {
          final it = l.itemId == null ? null : items[l.itemId!];
          if (it == null || l.qty <= 0) continue;
          final mq = qtyMilli(l.qty);
          final eff = (l.total * 1000 + mq ~/ 2) ~/ mq;
          if (eff != it['purchase_price']) {
            final sale = db.intScalar(
              'SELECT sale_price FROM items WHERE id=?',
              [l.itemId],
            );
            db.exec('UPDATE items SET purchase_price=? WHERE id=?', [
              eff,
              l.itemId,
            ]);
            db.exec(
              "INSERT INTO price_history(item_id, sale_price, purchase_price, source, changed_at) VALUES(?,?,?,'purchase_invoice',?)",
              [l.itemId, sale, eff, now],
            );
            items[l.itemId!] = {...it, 'purchase_price': eff};
          }
        }
      }
      return id;
    });
  }

  /// موجودی هیچ‌یک از کالاهای درگیر نباید منفی شود (مگر در تنظیمات مجاز شده باشد)
  void _assertStockOk(Set<int> itemIds) {
    if (settings.allowNegativeStock) return;
    for (final iid in itemIds) {
      final it = db.one('SELECT name, track_stock FROM items WHERE id=?', [
        iid,
      ]);
      if (it == null || it['track_stock'] != 1) continue;
      final stock = db.intScalar(
        'SELECT COALESCE(SUM(qty_milli),0) FROM stock_movements WHERE item_id=?',
        [iid],
      );
      if (stock < 0) {
        throw DomainError(
          'موجودی «${it['name']}» کافی نیست (موجودی پس از این عملیات: ${fmtQty(stock / 1000)}).',
        );
      }
    }
  }

  /// حذف منطقی؛ اگر پرداخت فعال دارد ممنوع. موجودی انبار به حالت قبل برمی‌گردد.
  void delete(int id) {
    db.transaction(() {
      final inv = db.one(
        'SELECT kind FROM invoices WHERE id=? AND deleted_at IS NULL',
        [id],
      );
      if (inv == null) throw DomainError('فاکتور پیدا نشد.');
      if (db.intScalar(
            'SELECT COUNT(*) FROM payments WHERE invoice_id=? AND deleted_at IS NULL',
            [id],
          ) >
          0) {
        throw DomainError(
          'این فاکتور پرداخت ثبت‌شده دارد؛ ابتدا پرداخت‌ها را حذف کنید.',
        );
      }
      final affected = <int>{
        for (final r in db.query(
          'SELECT DISTINCT item_id FROM stock_movements WHERE ref_invoice_id=?',
          [id],
        ))
          r['item_id'] as int,
      };
      db.exec('DELETE FROM stock_movements WHERE ref_invoice_id=?', [id]);
      db.exec('UPDATE invoices SET deleted_at=?, updated_at=? WHERE id=?', [
        nowIsoUtc(),
        nowIsoUtc(),
        id,
      ]);
      _assertStockOk(affected);
    });
  }
}
