/// کوئری‌های SQL گزارش و فهرست (پارامترها با ? و به ترتیب). فیلتر اختیاری: (? IS NULL OR col = ?) ← مقدار دو بار پاس داده می‌شود.
/// تعریف‌ها (برای تفکیک محاسبات):
///   فروش   = جمع ردیف‌های فاکتور فروش (تاریخ فاکتور)
///   بهای تمام‌شده (COGS) = تعداد × آخرین قیمت خریدِ ثبت‌شده در لحظه فروش
///   هزینه  = ردیف‌های فاکتور خرید از نوع «خدمت/آزاد» (خرید کالا هزینه نیست؛ هنگام فروش به COGS تبدیل می‌شود)
///   دریافتی/پرداختی = جدول پرداخت‌ها (تاریخ پرداخت) و ربطی به تاریخ فاکتور ندارد
library;

/// طرف‌حساب‌ها با مجموع فاکتورها و پرداخت‌ها. [kind, q, q, q, q]
const String qPartiesWithBalance = r'''
SELECT p.id, p.code, p.kind, p.name, p.mobile, p.description, p.sms_consent, p.is_active, p.created_at,
  COALESCE((SELECT SUM(i.total) FROM invoices i
            WHERE i.party_id = p.id AND i.deleted_at IS NULL
              AND i.kind = CASE p.kind WHEN 'customer' THEN 'sale' ELSE 'purchase' END), 0) AS total_amount,
  COALESCE((SELECT SUM(y.amount) FROM payments y
            WHERE y.party_id = p.id AND y.deleted_at IS NULL
              AND y.direction = CASE p.kind WHEN 'customer' THEN 'in' ELSE 'out' END), 0) AS paid_amount
FROM parties p
WHERE p.kind = ? AND p.deleted_at IS NULL
  AND (? = '' OR instr(p.name, ?) > 0 OR instr(COALESCE(p.mobile, ''), ?) > 0 OR instr(lower(p.code), lower(?)) > 0)
ORDER BY p.name''';

/// فهرست فاکتورها. [kind, from, to, party, party, number, number, status, status, status, status, status, limit, offset]
/// status: all | unpaid | partial | paid | open
const String qInvoiceList = r'''
SELECT * FROM (
  SELECT i.id, i.kind, i.number, i.date, i.total, i.party_id, COALESCE(p.name, i.party_name, '') AS party_name, i.description,
    COALESCE((SELECT SUM(y.amount) FROM payments y WHERE y.invoice_id = i.id AND y.deleted_at IS NULL), 0) AS paid
  FROM invoices i LEFT JOIN parties p ON p.id = i.party_id
  WHERE i.kind = ? AND i.deleted_at IS NULL AND i.date BETWEEN ? AND ?
    AND (? IS NULL OR i.party_id = ?)
    AND (? IS NULL OR i.number = ?)
)
WHERE (? = 'all'
   OR (? = 'unpaid' AND paid = 0 AND total > 0)
   OR (? = 'partial' AND paid > 0 AND paid < total)
   OR (? = 'paid' AND paid >= total)
   OR (? = 'open' AND paid < total))
ORDER BY date DESC, number DESC
LIMIT ? OFFSET ?''';

const String qInvoiceItems = r'''
SELECT id, item_id, title, item_kind, qty_milli, unit_price, discount, line_total, cost_unit
FROM invoice_items WHERE invoice_id = ? ORDER BY sort, id''';

/// کالا/خدمات با موجودی. [kind, kind, category, category, includeInactive, q, q, q]
const String qItemsList = r'''
SELECT it.id, it.code, it.kind, it.name, it.category_id, c.name AS category_name, it.description,
  it.sale_price, it.purchase_price, it.track_stock, it.min_stock_milli, it.is_active, it.created_at,
  COALESCE((SELECT SUM(m.qty_milli) FROM stock_movements m WHERE m.item_id = it.id), 0) AS stock_milli
FROM items it LEFT JOIN categories c ON c.id = it.category_id
WHERE it.deleted_at IS NULL
  AND (? = '' OR it.kind = ?)
  AND (? IS NULL OR it.category_id = ?)
  AND (? = 1 OR it.is_active = 1)
  AND (? = '' OR instr(lower(it.name), lower(?)) > 0 OR instr(lower(it.code), lower(?)) > 0)
ORDER BY it.name''';

/// فروش روزانه در سطح ردیف. [from, to, party, party, item, item]
const String qSalesByDay = r'''
SELECT i.date AS d, COUNT(DISTINCT i.id) AS cnt, SUM(ii.line_total) AS amount, SUM(ii.discount) AS discount,
       SUM((ii.cost_unit * ii.qty_milli + 500) / 1000) AS cogs
FROM invoice_items ii JOIN invoices i ON i.id = ii.invoice_id
WHERE i.kind = 'sale' AND i.deleted_at IS NULL AND i.date BETWEEN ? AND ?
  AND (? IS NULL OR i.party_id = ?) AND (? IS NULL OR ii.item_id = ?)
GROUP BY i.date''';

/// هزینه‌های روزانه (خرید از نوع خدمت/آزاد). [from, to, party, party, item, item]
const String qExpensesByDay = r'''
SELECT i.date AS d, SUM(ii.line_total) AS amount
FROM invoice_items ii JOIN invoices i ON i.id = ii.invoice_id
WHERE i.kind = 'purchase' AND ii.item_kind IN ('service', 'free') AND i.deleted_at IS NULL AND i.date BETWEEN ? AND ?
  AND (? IS NULL OR i.party_id = ?) AND (? IS NULL OR ii.item_id = ?)
GROUP BY i.date''';

/// خرید کالا (موجودی) روزانه. [from, to, party, party, item, item]
const String qGoodsPurchasesByDay = r'''
SELECT i.date AS d, SUM(ii.line_total) AS amount
FROM invoice_items ii JOIN invoices i ON i.id = ii.invoice_id
WHERE i.kind = 'purchase' AND ii.item_kind = 'product' AND i.deleted_at IS NULL AND i.date BETWEEN ? AND ?
  AND (? IS NULL OR i.party_id = ?) AND (? IS NULL OR ii.item_id = ?)
GROUP BY i.date''';

/// دریافتی/پرداختی روزانه. [from, to, party, party]
const String qCashByDay = r'''
SELECT y.date AS d, y.direction AS dir, SUM(y.amount) AS amount, COUNT(*) AS cnt
FROM payments y
WHERE y.deleted_at IS NULL AND y.date BETWEEN ? AND ? AND (? IS NULL OR y.party_id = ?)
GROUP BY y.date, y.direction''';

/// ریز هزینه‌ها بر اساس عنوان. [from, to, party, party, item, item]
const String qExpenseBreakdown = r'''
SELECT ii.title AS title, SUM(ii.line_total) AS amount, COUNT(*) AS cnt
FROM invoice_items ii JOIN invoices i ON i.id = ii.invoice_id
WHERE i.kind = 'purchase' AND ii.item_kind IN ('service', 'free') AND i.deleted_at IS NULL AND i.date BETWEEN ? AND ?
  AND (? IS NULL OR i.party_id = ?) AND (? IS NULL OR ii.item_id = ?)
GROUP BY ii.title ORDER BY amount DESC''';

/// ردیف‌های هزینه. [from, to, party, party, item, item, limit]
const String qExpenseDetails = r'''
SELECT i.date AS date, i.number AS number, COALESCE(p.name, i.party_name, '') AS party, ii.title AS title,
       ii.qty_milli AS qty_milli, ii.unit_price AS unit_price, ii.discount AS discount, ii.line_total AS amount
FROM invoice_items ii JOIN invoices i ON i.id = ii.invoice_id LEFT JOIN parties p ON p.id = i.party_id
WHERE i.kind = 'purchase' AND ii.item_kind IN ('service', 'free') AND i.deleted_at IS NULL AND i.date BETWEEN ? AND ?
  AND (? IS NULL OR i.party_id = ?) AND (? IS NULL OR ii.item_id = ?)
ORDER BY i.date DESC, i.number DESC, ii.id LIMIT ?''';

/// فروش به تفکیک کالا یا خدمت. [from, to, kindA, kindB, party, party, item, item]
/// کالا: ('product','product')   خدمات: ('service','free')
const String qItemSales = r'''
SELECT COALESCE(it.code, '') AS code, COALESCE(it.name, ii.title) AS name, ii.item_kind AS item_kind,
       SUM(ii.qty_milli) AS qty_milli, SUM(ii.line_total) AS amount,
       SUM((ii.cost_unit * ii.qty_milli + 500) / 1000) AS cogs, COUNT(DISTINCT i.id) AS invoices
FROM invoice_items ii JOIN invoices i ON i.id = ii.invoice_id LEFT JOIN items it ON it.id = ii.item_id
WHERE i.kind = 'sale' AND i.deleted_at IS NULL AND i.date BETWEEN ? AND ? AND ii.item_kind IN (?, ?)
  AND (? IS NULL OR i.party_id = ?) AND (? IS NULL OR ii.item_id = ?)
GROUP BY COALESCE(CAST(ii.item_id AS TEXT), ii.title)
ORDER BY amount DESC''';

/// گزارش پرداخت‌ها. [from, to, party, party, method, method, direction, direction, limit]
const String qPaymentsReport = r'''
SELECT y.id AS id, y.date AS date, y.direction AS direction, y.method AS method, y.amount AS amount,
       COALESCE(y.description, '') AS description, COALESCE(p.name, i.party_name, '') AS party,
       i.number AS inv_number, i.kind AS inv_kind, y.invoice_id AS invoice_id, y.party_id AS party_id
FROM payments y LEFT JOIN parties p ON p.id = y.party_id LEFT JOIN invoices i ON i.id = y.invoice_id
WHERE y.deleted_at IS NULL AND y.date BETWEEN ? AND ?
  AND (? IS NULL OR y.party_id = ?)
  AND (? = '' OR y.method = ?) AND (? = '' OR y.direction = ?)
ORDER BY y.date DESC, y.id DESC LIMIT ?''';

/// فاکتورهای تسویه‌نشده. [kind, from, to, party, party, limit]
const String qUnsettledInvoices = r'''
SELECT * FROM (
  SELECT i.id AS id, i.number AS number, i.date AS date, i.total AS total, COALESCE(p.name, i.party_name, '') AS party,
    COALESCE((SELECT SUM(y.amount) FROM payments y WHERE y.invoice_id = i.id AND y.deleted_at IS NULL), 0) AS paid
  FROM invoices i LEFT JOIN parties p ON p.id = i.party_id
  WHERE i.kind = ? AND i.deleted_at IS NULL AND i.date BETWEEN ? AND ? AND (? IS NULL OR i.party_id = ?)
)
WHERE paid < total
ORDER BY date, number LIMIT ?''';

/// مانده کل فاکتورهای تسویه‌نشده (فروش) برای داشبورد: [count, remaining]
const String qUnsettledSummary = r'''
SELECT COUNT(*) AS cnt, COALESCE(SUM(total - paid), 0) AS remaining FROM (
  SELECT i.total AS total,
    COALESCE((SELECT SUM(y.amount) FROM payments y WHERE y.invoice_id = i.id AND y.deleted_at IS NULL), 0) AS paid
  FROM invoices i WHERE i.kind = 'sale' AND i.deleted_at IS NULL
) WHERE paid < total''';

/// پرداخت‌های یک طرف‌حساب یا فاکتور. [party, party, invoice, invoice, limit]
const String qPaymentsOf = r'''
SELECT y.id, y.invoice_id, y.party_id, y.direction, y.method, y.amount, y.date, COALESCE(y.description, '') AS description,
       i.number AS inv_number
FROM payments y LEFT JOIN invoices i ON i.id = y.invoice_id
WHERE y.deleted_at IS NULL AND (? IS NULL OR y.party_id = ?) AND (? IS NULL OR y.invoice_id = ?)
ORDER BY y.date DESC, y.id DESC LIMIT ?''';

/// موجودی فعلی یک کالا به‌جز حرکات یک فاکتور. [item, invoice]
const String qStockExcludingInvoice = r'''
SELECT COALESCE(SUM(qty_milli), 0) FROM stock_movements
WHERE item_id = ? AND (ref_invoice_id IS NULL OR ref_invoice_id <> ?)''';

/// تاریخچه پیامک. [limit]
const String qSmsHistory = r'''
SELECT s.id, s.party_id, s.mobile, s.message, s.kind, s.status, s.error, s.batch_id, s.created_at,
       COALESCE(p.name, '') AS name
FROM sms_log s LEFT JOIN parties p ON p.id = s.party_id
ORDER BY s.id DESC LIMIT ?''';
