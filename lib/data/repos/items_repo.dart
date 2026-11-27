import '../../core/utils/format.dart';
import '../../domain/invoice_calc.dart';
import '../database.dart';
import '../models.dart';
import '../queries.dart';

/// کالا، خدمات، دسته‌بندی، تاریخچه قیمت و موجودی
class ItemsRepo {
  final AppDatabase db;
  ItemsRepo(this.db);

  // ---- دسته‌بندی ----
  List<Category> categories(String kind) => db
      .query(
        'SELECT id, name, kind FROM categories WHERE kind=? ORDER BY name',
        [kind],
      )
      .map(
        (r) =>
            Category(r['id'] as int, r['name'] as String, r['kind'] as String),
      )
      .toList();

  int addCategory(String kind, String name) {
    final n = normalizeFa(name);
    if (n.isEmpty || n.length > 60) {
      throw DomainError('نام دسته‌بندی معتبر نیست.');
    }
    db.exec('INSERT INTO categories(name, kind) VALUES(?,?)', [n, kind]);
    return db.lastInsertId;
  }

  void deleteCategory(int id) {
    if (db.intScalar(
          'SELECT COUNT(*) FROM items WHERE category_id=? AND deleted_at IS NULL',
          [id],
        ) >
        0) {
      throw DomainError('این دسته‌بندی در کالا/خدمات استفاده شده است.');
    }
    db.exec('DELETE FROM categories WHERE id=?', [id]);
  }

  // ---- کالا و خدمات ----
  List<Item> list({
    String kind = '',
    int? categoryId,
    bool includeInactive = true,
    String query = '',
  }) {
    final q = normalizeFa(enDigits(query));
    return db
        .query(qItemsList, [
          kind,
          kind,
          categoryId,
          categoryId,
          includeInactive ? 1 : 0,
          q,
          q,
          q,
        ])
        .map(Item.fromRow)
        .toList();
  }

  Item? get(int id) {
    for (final r in db.query(qItemsList, ['', '', null, null, 1, '', '', ''])) {
      if (r['id'] == id) return Item.fromRow(r);
    }
    return null;
  }

  String nextCode(String kind) {
    final p = kind == 'product' ? 'P' : 'S';
    final n = db.intScalar(
      "SELECT COALESCE(MAX(CAST(SUBSTR(code, 2) AS INTEGER)), 0) + 1 FROM items WHERE kind=? AND code LIKE '$p%'",
      [kind],
    );
    return '$p${n.toString().padLeft(4, '0')}';
  }

  String? _validate(String name, int sale, int purchase, String description) {
    if (name.isEmpty) return 'نام را وارد کنید.';
    if (name.length > 120) return 'نام بیش از حد طولانی است.';
    if (sale < 0 || purchase < 0) return 'قیمت نمی‌تواند منفی باشد.';
    if (sale > kMaxPrice || purchase > kMaxPrice) {
      return 'قیمت بیش از حد مجاز است.';
    }
    if (description.length > 500) return 'توضیحات بیش از حد طولانی است.';
    return null;
  }

  int create({
    required String kind,
    required String name,
    String? code,
    int? categoryId,
    String description = '',
    required int salePrice,
    int purchasePrice = 0,
    bool trackStock = true,
    int openingStockMilli = 0,
    int minStockMilli = 0,
    String? date,
  }) {
    final n = normalizeFa(name);
    final err = _validate(n, salePrice, purchasePrice, description);
    if (err != null) throw DomainError(err);
    if (openingStockMilli < 0 || minStockMilli < 0) {
      throw DomainError('موجودی نمی‌تواند منفی باشد.');
    }
    final isProduct = kind == 'product';
    final track = isProduct && trackStock;
    return db.transaction(() {
      final c = (code == null || code.trim().isEmpty)
          ? nextCode(kind)
          : code.trim();
      final now = nowIsoUtc();
      db.exec(
        'INSERT INTO items(code, kind, name, category_id, description, sale_price, purchase_price, track_stock, min_stock_milli, created_at) VALUES(?,?,?,?,?,?,?,?,?,?)',
        [
          c,
          kind,
          n,
          categoryId,
          description.trim().isEmpty ? null : description.trim(),
          salePrice,
          purchasePrice,
          track ? 1 : 0,
          minStockMilli,
          now,
        ],
      );
      final id = db.lastInsertId;
      db.exec(
        'INSERT INTO price_history(item_id, sale_price, purchase_price, source, changed_at) VALUES(?,?,?,?,?)',
        [id, salePrice, purchasePrice, 'manual', now],
      );
      if (track && openingStockMilli > 0) {
        db.exec(
          "INSERT INTO stock_movements(item_id, qty_milli, reason, date, note, created_at) VALUES(?,?,'opening',?,?,?)",
          [
            id,
            openingStockMilli,
            date ?? now.substring(0, 10),
            'موجودی اولیه',
            now,
          ],
        );
      }
      return id;
    });
  }

  void update(
    int id, {
    required String name,
    int? categoryId,
    String description = '',
    required int salePrice,
    required int purchasePrice,
    required bool trackStock,
    int minStockMilli = 0,
    required bool isActive,
  }) {
    final n = normalizeFa(name);
    final err = _validate(n, salePrice, purchasePrice, description);
    if (err != null) throw DomainError(err);
    db.transaction(() {
      final old = db.one(
        'SELECT kind, sale_price, purchase_price, track_stock FROM items WHERE id=? AND deleted_at IS NULL',
        [id],
      );
      if (old == null) throw DomainError('مورد پیدا نشد.');
      final isProduct = old['kind'] == 'product';
      db.exec(
        'UPDATE items SET name=?, category_id=?, description=?, sale_price=?, purchase_price=?, track_stock=?, min_stock_milli=?, is_active=? WHERE id=?',
        [
          n,
          categoryId,
          description.trim().isEmpty ? null : description.trim(),
          salePrice,
          purchasePrice,
          (isProduct && trackStock) ? 1 : 0,
          minStockMilli,
          isActive ? 1 : 0,
          id,
        ],
      );
      if (old['sale_price'] != salePrice ||
          old['purchase_price'] != purchasePrice) {
        db.exec(
          'INSERT INTO price_history(item_id, sale_price, purchase_price, source, changed_at) VALUES(?,?,?,?,?)',
          [id, salePrice, purchasePrice, 'manual', nowIsoUtc()],
        );
      }
    });
  }

  /// حذف منطقی: فاکتورهای قبلی با نام و قیمت ثبت‌شده در خودشان سالم می‌مانند.
  void delete(int id) {
    final changed = db.exec(
      'UPDATE items SET deleted_at=?, is_active=0 WHERE id=? AND deleted_at IS NULL',
      [nowIsoUtc(), id],
    );
    if (changed == 0) throw DomainError('مورد پیدا نشد.');
  }

  List<Map<String, Object?>> priceHistory(int itemId) => db.query(
    'SELECT sale_price, purchase_price, source, changed_at FROM price_history WHERE item_id=? ORDER BY id DESC',
    [itemId],
  );

  // ---- موجودی ----
  int stockMilli(int itemId) => db.intScalar(
    'SELECT COALESCE(SUM(qty_milli),0) FROM stock_movements WHERE item_id=?',
    [itemId],
  );

  /// تعدیل دستی موجودی (مثبت یا منفی)
  void adjustStock(
    int itemId,
    int deltaMilli, {
    required String date,
    String note = '',
    required bool allowNegative,
  }) {
    if (deltaMilli == 0) throw DomainError('مقدار تعدیل صفر است.');
    db.transaction(() {
      final it = db.one(
        'SELECT kind, track_stock FROM items WHERE id=? AND deleted_at IS NULL',
        [itemId],
      );
      if (it == null) throw DomainError('مورد پیدا نشد.');
      if (it['kind'] != 'product' || it['track_stock'] != 1) {
        throw DomainError('برای این مورد موجودی نگهداری نمی‌شود.');
      }
      if (!allowNegative && stockMilli(itemId) + deltaMilli < 0) {
        throw DomainError('موجودی پس از تعدیل منفی می‌شود.');
      }
      db.exec(
        "INSERT INTO stock_movements(item_id, qty_milli, reason, date, note, created_at) VALUES(?,?,'adjust',?,?,?)",
        [
          itemId,
          deltaMilli,
          date,
          note.trim().isEmpty ? null : note.trim(),
          nowIsoUtc(),
        ],
      );
    });
  }

  List<Map<String, Object?>> stockHistory(
    int itemId, {
    int limit = 100,
  }) => db.query(
    '''SELECT m.date, m.qty_milli, m.reason, m.note, i.number AS inv_number, i.kind AS inv_kind
         FROM stock_movements m LEFT JOIN invoices i ON i.id = m.ref_invoice_id
         WHERE m.item_id=? ORDER BY m.date DESC, m.id DESC LIMIT ?''',
    [itemId, limit],
  );
}
