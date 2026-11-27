/// ساختار دیتابیس محلی (SQLite). هر عنصر لیست یک دستور است.
/// - مبالغ: عدد صحیح (تومان). مقدارها (qty): عدد صحیح «هزارم» (qty_milli) تا جمع‌ها دقیق باشند.
/// - تاریخ‌ها: میلادی ISO (yyyy-MM-dd)؛ زمان‌های ثبت: ISO-8601 UTC.
/// - حذف: منطقی (deleted_at)؛ سوابق مالی هرگز فیزیکی حذف نمی‌شوند.
/// - تریگرها تضمین می‌کنند حتی در صورت باگ برنامه، پرداخت‌ها از مبلغ فاکتور بیشتر نشوند.
const int kSchemaVersion = 1;

const List<String> kSchemaV1 = [
  r'''
CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT
)''',
  r'''
CREATE TABLE categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('product','service')),
  UNIQUE (name, kind)
)''',
  r'''
CREATE TABLE parties (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL UNIQUE,
  kind TEXT NOT NULL CHECK (kind IN ('customer','supplier')),
  name TEXT NOT NULL CHECK (length(trim(name)) > 0),
  mobile TEXT CHECK (mobile IS NULL OR (length(mobile) = 11 AND mobile LIKE '09%')),
  description TEXT,
  sms_consent INTEGER NOT NULL DEFAULT 0 CHECK (sms_consent IN (0,1)),
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
  created_at TEXT NOT NULL,
  deleted_at TEXT
)''',
  r'''
CREATE UNIQUE INDEX ux_parties_mobile ON parties(kind, mobile)
  WHERE mobile IS NOT NULL AND deleted_at IS NULL''',
  r'''
CREATE INDEX ix_parties_name ON parties(name)''',
  r'''
CREATE TABLE items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL UNIQUE,
  kind TEXT NOT NULL CHECK (kind IN ('product','service')),
  name TEXT NOT NULL CHECK (length(trim(name)) > 0),
  category_id INTEGER REFERENCES categories(id),
  description TEXT,
  sale_price INTEGER NOT NULL DEFAULT 0 CHECK (sale_price >= 0),
  purchase_price INTEGER NOT NULL DEFAULT 0 CHECK (purchase_price >= 0),
  track_stock INTEGER NOT NULL DEFAULT 0 CHECK (track_stock IN (0,1)),
  min_stock_milli INTEGER NOT NULL DEFAULT 0 CHECK (min_stock_milli >= 0),
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
  created_at TEXT NOT NULL,
  deleted_at TEXT
)''',
  r'''
CREATE INDEX ix_items_name ON items(name)''',
  r'''
CREATE TABLE price_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  item_id INTEGER NOT NULL REFERENCES items(id),
  sale_price INTEGER NOT NULL,
  purchase_price INTEGER NOT NULL,
  source TEXT NOT NULL DEFAULT 'manual',
  changed_at TEXT NOT NULL
)''',
  r'''
CREATE TABLE invoices (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kind TEXT NOT NULL CHECK (kind IN ('sale','purchase')),
  number INTEGER NOT NULL CHECK (number > 0),
  party_id INTEGER REFERENCES parties(id),
  party_name TEXT,
  date TEXT NOT NULL,
  description TEXT,
  total INTEGER NOT NULL CHECK (total >= 0),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  UNIQUE (kind, number)
)''',
  r'''
CREATE INDEX ix_invoices_date ON invoices(kind, date)''',
  r'''
CREATE INDEX ix_invoices_party ON invoices(party_id)''',
  r'''
CREATE TABLE invoice_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  invoice_id INTEGER NOT NULL REFERENCES invoices(id),
  item_id INTEGER REFERENCES items(id),
  title TEXT NOT NULL,
  item_kind TEXT NOT NULL CHECK (item_kind IN ('product','service','free')),
  qty_milli INTEGER NOT NULL CHECK (qty_milli > 0),
  unit_price INTEGER NOT NULL CHECK (unit_price >= 0),
  discount INTEGER NOT NULL DEFAULT 0 CHECK (discount >= 0),
  line_total INTEGER NOT NULL CHECK (line_total >= 0),
  cost_unit INTEGER NOT NULL DEFAULT 0 CHECK (cost_unit >= 0),
  sort INTEGER NOT NULL DEFAULT 0
)''',
  r'''
CREATE INDEX ix_invitems_invoice ON invoice_items(invoice_id)''',
  r'''
CREATE INDEX ix_invitems_item ON invoice_items(item_id)''',
  r'''
CREATE TABLE stock_movements (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  item_id INTEGER NOT NULL REFERENCES items(id),
  qty_milli INTEGER NOT NULL CHECK (qty_milli <> 0),
  reason TEXT NOT NULL CHECK (reason IN ('opening','sale','purchase','adjust')),
  ref_invoice_id INTEGER REFERENCES invoices(id),
  date TEXT NOT NULL,
  note TEXT,
  created_at TEXT NOT NULL
)''',
  r'''
CREATE INDEX ix_stock_item ON stock_movements(item_id)''',
  r'''
CREATE INDEX ix_stock_invoice ON stock_movements(ref_invoice_id)''',
  r'''
CREATE TABLE payments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  party_id INTEGER REFERENCES parties(id),
  invoice_id INTEGER REFERENCES invoices(id),
  direction TEXT NOT NULL CHECK (direction IN ('in','out')),
  method TEXT NOT NULL CHECK (method IN ('cash','card_transfer','pos')),
  amount INTEGER NOT NULL CHECK (amount > 0),
  date TEXT NOT NULL,
  description TEXT,
  created_at TEXT NOT NULL,
  deleted_at TEXT,
  CHECK (party_id IS NOT NULL OR invoice_id IS NOT NULL)
)''',
  r'''
CREATE INDEX ix_payments_date ON payments(date)''',
  r'''
CREATE INDEX ix_payments_invoice ON payments(invoice_id)''',
  r'''
CREATE INDEX ix_payments_party ON payments(party_id)''',
  r'''
CREATE TABLE sms_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  party_id INTEGER REFERENCES parties(id),
  mobile TEXT NOT NULL,
  message TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('info','promo','occasion')),
  status TEXT NOT NULL CHECK (status IN ('sent','failed')),
  error TEXT,
  batch_id TEXT NOT NULL,
  created_at TEXT NOT NULL
)''',
  r'''
CREATE INDEX ix_sms_created ON sms_log(created_at)''',

  // ---- تریگرهای یکپارچگی ----
  // جهت پرداخت باید با نوع فاکتور هم‌خوان باشد و طرف‌حساب پرداخت با طرف‌حساب فاکتور یکی باشد.
  r'''
CREATE TRIGGER trg_payment_ins BEFORE INSERT ON payments
WHEN NEW.invoice_id IS NOT NULL
BEGIN
  SELECT RAISE(ABORT, 'invoice_not_found')
    WHERE NOT EXISTS (SELECT 1 FROM invoices WHERE id = NEW.invoice_id AND deleted_at IS NULL);
  SELECT RAISE(ABORT, 'direction_mismatch')
    WHERE (SELECT kind FROM invoices WHERE id = NEW.invoice_id) <> CASE NEW.direction WHEN 'in' THEN 'sale' ELSE 'purchase' END;
  SELECT RAISE(ABORT, 'party_mismatch')
    WHERE (SELECT party_id FROM invoices WHERE id = NEW.invoice_id) IS NOT NEW.party_id;
  SELECT RAISE(ABORT, 'overpay')
    WHERE NEW.deleted_at IS NULL AND
      (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE invoice_id = NEW.invoice_id AND deleted_at IS NULL) + NEW.amount
        > (SELECT total FROM invoices WHERE id = NEW.invoice_id);
END''',
  // تخصیص/ویرایش پرداخت نیز همان قواعد را رعایت کند
  r'''
CREATE TRIGGER trg_payment_upd BEFORE UPDATE OF invoice_id, amount, party_id, direction, deleted_at ON payments
WHEN NEW.invoice_id IS NOT NULL AND NEW.deleted_at IS NULL
BEGIN
  SELECT RAISE(ABORT, 'invoice_not_found')
    WHERE NOT EXISTS (SELECT 1 FROM invoices WHERE id = NEW.invoice_id AND deleted_at IS NULL);
  SELECT RAISE(ABORT, 'direction_mismatch')
    WHERE (SELECT kind FROM invoices WHERE id = NEW.invoice_id) <> CASE NEW.direction WHEN 'in' THEN 'sale' ELSE 'purchase' END;
  SELECT RAISE(ABORT, 'party_mismatch')
    WHERE (SELECT party_id FROM invoices WHERE id = NEW.invoice_id) IS NOT NEW.party_id;
  SELECT RAISE(ABORT, 'overpay')
    WHERE (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE invoice_id = NEW.invoice_id AND deleted_at IS NULL AND id <> NEW.id) + NEW.amount
        > (SELECT total FROM invoices WHERE id = NEW.invoice_id);
END''',
  // مبلغ فاکتور نباید کمتر از مجموع پرداخت‌های آن شود
  r'''
CREATE TRIGGER trg_invoice_total_upd BEFORE UPDATE OF total ON invoices
BEGIN
  SELECT RAISE(ABORT, 'total_below_paid')
    WHERE NEW.total < (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE invoice_id = NEW.id AND deleted_at IS NULL);
END''',
  // فاکتوری که پرداخت فعال دارد حذف منطقی نشود
  r'''
CREATE TRIGGER trg_invoice_delete BEFORE UPDATE OF deleted_at ON invoices
WHEN NEW.deleted_at IS NOT NULL AND OLD.deleted_at IS NULL
BEGIN
  SELECT RAISE(ABORT, 'has_payments')
    WHERE EXISTS (SELECT 1 FROM payments WHERE invoice_id = NEW.id AND deleted_at IS NULL);
END''',
];

/// ایندکس ۰ = مهاجرت به نسخه ۱ ... (برای نسخه‌های بعدی اینجا اضافه شود و kSchemaVersion بالا برود)
const List<List<String>> kMigrations = [kSchemaV1];

const Map<String, String> kDefaultSettings = {
  'business_name': '',
  'business_phone': '',
  'business_address': '',
  'invoice_footer': '',
  'allow_negative_stock': '0',
  'update_cost_on_purchase': '1',
  'last_backup_at': '',
};
