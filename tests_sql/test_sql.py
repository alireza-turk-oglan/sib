"""تست دستورهای SQL برنامه (schema.dart و queries.dart) روی SQLite واقعی."""
import re, sqlite3, sys

def load_strings(path):
    t = open(path, encoding='utf-8').read()
    return t

def schema():
    t = load_strings('lib/data/schema.dart')
    body = t.split('const List<String> kSchemaV1 = [')[1].split('\n];')[0]
    return re.findall(r"r'''(.*?)'''", body, re.S)

def queries():
    t = load_strings('lib/data/queries.dart')
    return dict(re.findall(r"const String (\w+) = r'''(.*?)''';", t, re.S))

passed = failed = 0
def check(name, cond, extra=''):
    global passed, failed
    if cond: passed += 1; print('  ok  ', name)
    else: failed += 1; print('  FAIL', name, extra)

def fresh():
    db = sqlite3.connect(':memory:'); db.row_factory = sqlite3.Row
    db.execute('PRAGMA foreign_keys=ON')
    for s in schema(): db.execute(s)
    return db

def raises(db, sql, args=(), msg=''):
    try: db.execute(sql, args)
    except sqlite3.DatabaseError as e: return msg in str(e)
    return False

Q = queries()
NOW = '2026-11-07T10:00:00Z'
stmts = schema()
check(f'schema statements parsed ({len(stmts)})', len(stmts) >= 25)
check('all queries parsed', len(Q) >= 15, str(len(Q)))

db = fresh()
ex = lambda sql, a=(): db.execute(sql, a)
# ---- داده نمونه ----
ex("INSERT INTO parties(code,kind,name,mobile,sms_consent,created_at) VALUES('C0001','customer','علی رضایی','09121111111',1,?)", (NOW,))
ex("INSERT INTO parties(code,kind,name,mobile,created_at) VALUES('C0002','customer','مریم احمدی','09122222222',?)", (NOW,))
ex("INSERT INTO parties(code,kind,name,created_at) VALUES('V0001','supplier','تأمین‌کننده الف',?)", (NOW,))
ex("INSERT INTO categories(name,kind) VALUES('لوازم','product')")
ex("INSERT INTO items(code,kind,name,category_id,sale_price,purchase_price,track_stock,created_at) VALUES('P0001','product','قلم',1,10000,6000,1,?)", (NOW,))
ex("INSERT INTO items(code,kind,name,sale_price,created_at) VALUES('S0001','service','تعمیر',50000,?)", (NOW,))
ex("INSERT INTO stock_movements(item_id,qty_milli,reason,date,created_at) VALUES(1,100000,'opening','2026-10-01',?)", (NOW,))

def inv(kind, number, party, date, total):
    ex("INSERT INTO invoices(kind,number,party_id,date,total,created_at,updated_at) VALUES(?,?,?,?,?,?,?)", (kind, number, party, date, total, NOW, NOW))
    return db.execute('SELECT last_insert_rowid()').fetchone()[0]
def line(i, item, title, kind, qty_milli, price, disc, cost, sort=0, sign=-1):
    total = (qty_milli * price + 500) // 1000 - disc
    ex("INSERT INTO invoice_items(invoice_id,item_id,title,item_kind,qty_milli,unit_price,discount,line_total,cost_unit,sort) VALUES(?,?,?,?,?,?,?,?,?,?)", (i, item, title, kind, qty_milli, price, disc, total, cost, sort))
    if kind == 'product': ex("INSERT INTO stock_movements(item_id,qty_milli,reason,ref_invoice_id,date,created_at) VALUES(?,?,?,?,?,?)", (item, sign * qty_milli, 'sale' if sign < 0 else 'purchase', i, '2026-11-01', NOW))
    return total

# فروش ۱: علی، ۱ آبان: ۱۰ قلم (۱۰۰٬۰۰۰) + تعمیر ۱ (۵۰٬۰۰۰ با تخفیف ۵٬۰۰۰) = ۱۴۵٬۰۰۰
i1 = inv('sale', 1, 1, '2026-11-01', 145000)
line(i1, 1, 'قلم', 'product', 10000, 10000, 0, 6000); line(i1, 2, 'تعمیر', 'service', 1000, 50000, 5000, 0, 1)
# فروش ۲: مریم، ۳ آبان: ۲٫۵ قلم = ۲۵٬۰۰۰ ؛ + ردیف آزاد «ارسال» ۳٬۰۰۰
i2 = inv('sale', 2, 2, '2026-11-03', 28000)
line(i2, 1, 'قلم', 'product', 2500, 10000, 0, 6000); line(i2, None, 'ارسال', 'free', 1000, 3000, 0, 0, 1)
# فروش ۳: بدون طرف‌حساب (نقدی) ۵ نوامبر ۱۰٬۰۰۰
i3 = inv('sale', 3, None, '2026-11-05', 10000)
line(i3, 1, 'قلم', 'product', 1000, 10000, 0, 6000)
# خرید ۱: تأمین‌کننده، ۲ آبان: ۵۰ قلم × ۶٬۲۰۰ = ۳۱۰٬۰۰۰ ؛ هزینه اجاره (آزاد) ۱۰۰٬۰۰۰
p1 = inv('purchase', 1, 3, '2026-11-02', 410000)
line(p1, 1, 'قلم', 'product', 50000, 6200, 0, 0, sign=1)
line(p1, None, 'اجاره', 'free', 1000, 100000, 0, 0, 1)
# پرداخت‌ها
ex("INSERT INTO payments(party_id,invoice_id,direction,method,amount,date,created_at) VALUES(1,?,'in','cash',100000,'2026-11-01',?)", (i1, NOW))
ex("INSERT INTO payments(party_id,invoice_id,direction,method,amount,date,created_at) VALUES(2,?,'in','pos',28000,'2026-11-03',?)", (i2, NOW))
ex("INSERT INTO payments(party_id,invoice_id,direction,method,amount,date,created_at) VALUES(NULL,?,'in','cash',10000,'2026-11-05',?)", (i3, NOW))
ex("INSERT INTO payments(party_id,invoice_id,direction,method,amount,date,created_at) VALUES(3,?,'out','card_transfer',200000,'2026-11-02',?)", (p1, NOW))
ex("INSERT INTO payments(party_id,invoice_id,direction,method,amount,date,created_at) VALUES(2,NULL,'in','cash',7000,'2026-11-04',?)", (NOW,))  # بستانکاری عمومی مریم
db.commit()

R, A = ('2026-11-01', '2026-11-30'), None
q = lambda name, *a: db.execute(Q[name], a).fetchall()

print('-- تفکیک فروش / بهای تمام‌شده / هزینه / دریافتی')
rows = q('qSalesByDay', *R, A, A, A, A)
check('فروش به تفکیک روز', {r['d']: r['amount'] for r in rows} == {'2026-11-01': 145000, '2026-11-03': 28000, '2026-11-05': 10000})
check('تعداد فاکتور', {r['d']: r['cnt'] for r in rows}['2026-11-01'] == 1)
check('تخفیف ثبت‌شده', {r['d']: r['discount'] for r in rows}['2026-11-01'] == 5000)
cogs = sum(r['cogs'] for r in rows)
check('بهای تمام‌شده = (۱۰+۲٫۵+۱)×۶۰۰۰ = ۸۱٬۰۰۰', cogs == 81000, cogs)
exp = q('qExpensesByDay', *R, A, A, A, A); check('هزینه فقط اجاره (خرید کالا هزینه نیست)', sum(r['amount'] for r in exp) == 100000)
gp = q('qGoodsPurchasesByDay', *R, A, A, A, A); check('خرید کالا جداگانه: ۳۱۰٬۰۰۰', sum(r['amount'] for r in gp) == 310000)
cash = {(r['d'], r['dir']): r['amount'] for r in q('qCashByDay', *R, A, A)}
check('دریافتی روز ۱ آبان', cash[('2026-11-01', 'in')] == 100000)
check('فروش اعتباری در دریافتی نیامده (کل دریافتی=۱۴۵٬۰۰۰)', sum(v for (d, k), v in cash.items() if k == 'in') == 145000)
check('پرداختی به تأمین‌کننده', cash[('2026-11-02', 'out')] == 200000)
revenue, total_exp = sum(r['amount'] for r in rows), sum(r['amount'] for r in exp)
check('سود خالص = فروش − COGS − هزینه = ۱۸۳٬۰۰۰−۸۱٬۰۰۰−۱۰۰٬۰۰۰ = ۲٬۰۰۰', revenue - cogs - total_exp == 2000, revenue - cogs - total_exp)
f = q('qSalesByDay', *R, 1, 1, A, A); check('فیلتر مشتری', sum(r['amount'] for r in f) == 145000)
f = q('qSalesByDay', *R, A, A, 2, 2); check('فیلتر خدمت', sum(r['amount'] for r in f) == 45000)
check('بازه خالی', q('qSalesByDay', '2026-12-01', '2026-12-31', A, A, A, A) == [])

print('-- گزارش کالا/خدمات')
prod = q('qItemSales', *R, 'product', 'product', A, A, A, A)
check('فروش کالا: یک ردیف، ۱۳٫۵ قلم، ۱۳۵٬۰۰۰', len(prod) == 1 and prod[0]['qty_milli'] == 13500 and prod[0]['amount'] == 135000, [dict(p) for p in prod])
check('COGS کالا ۸۱٬۰۰۰', prod[0]['cogs'] == 81000)
svc = q('qItemSales', *R, 'service', 'free', A, A, A, A)
check('خدمات شامل ردیف آزاد', sorted(r['name'] for r in svc) == ['ارسال', 'تعمیر'], [dict(r) for r in svc])
check('مرتب بر اساس مبلغ', svc[0]['amount'] >= svc[-1]['amount'])
eb = q('qExpenseBreakdown', *R, A, A, A, A); check('ریز هزینه', [(r['title'], r['amount']) for r in eb] == [('اجاره', 100000)])
ed = q('qExpenseDetails', *R, A, A, A, A, 100); check('ردیف‌های هزینه', len(ed) == 1 and ed[0]['party'] == 'تأمین‌کننده الف')

print('-- بدهی، بستانکاری، فاکتورهای تسویه‌نشده')
pb = {r['name']: r['total_amount'] - r['paid_amount'] for r in q('qPartiesWithBalance', 'customer', '', '', '', '')}
check('مانده علی = ۱۴۵٬۰۰۰−۱۰۰٬۰۰۰ = ۴۵٬۰۰۰ بدهکار', pb['علی رضایی'] == 45000)
check('مانده مریم = ۲۸٬۰۰۰−(۲۸٬۰۰۰+۷٬۰۰۰) = −۷٬۰۰۰ بستانکار', pb['مریم احمدی'] == -7000, pb)
sb = {r['name']: r['total_amount'] - r['paid_amount'] for r in q('qPartiesWithBalance', 'supplier', '', '', '', '')}
check('بدهی ما به تأمین‌کننده = ۴۱۰٬۰۰۰−۲۰۰٬۰۰۰', sb['تأمین‌کننده الف'] == 210000)
check('جست‌وجوی نام', [r['name'] for r in q('qPartiesWithBalance', 'customer', 'مریم', 'مریم', 'مریم', 'مریم')] == ['مریم احمدی'])
check('جست‌وجوی موبایل', len(q('qPartiesWithBalance', 'customer', '0912111', '0912111', '0912111', '0912111')) == 1)
check('جست‌وجوی کاراکتر % مثل wildcard رفتار نمی‌کند', q('qPartiesWithBalance', 'customer', '%', '%', '%', '%') == [])
un = q('qUnsettledInvoices', 'sale', '2000-01-01', '2100-01-01', A, A, 100)
check('تسویه‌نشده فروش: فقط فاکتور ۱ با ۴۵٬۰۰۰ باقی‌مانده', [(r['number'], r['total'] - r['paid']) for r in un] == [(1, 45000)], [dict(r) for r in un])
s = q('qUnsettledSummary')[0]; check('خلاصه تسویه‌نشده', (s['cnt'], s['remaining']) == (1, 45000))
un_p = q('qUnsettledInvoices', 'purchase', '2000-01-01', '2100-01-01', A, A, 100); check('خرید تسویه‌نشده ۲۱۰٬۰۰۰', un_p[0]['total'] - un_p[0]['paid'] == 210000)

print('-- فهرست فاکتور و فیلتر وضعیت')
lst = lambda st, party=A, num=A: q('qInvoiceList', 'sale', '2000-01-01', '2100-01-01', party, party, num, num, st, st, st, st, st, 100, 0)
check('همه', [r['number'] for r in lst('all')] == [3, 2, 1])
check('پرداخت‌نشده/جزئی', [r['number'] for r in lst('partial')] == [1] and lst('unpaid') == [])
check('تسویه‌شده', sorted(r['number'] for r in lst('paid')) == [2, 3])
check('باز (open)', [r['number'] for r in lst('open')] == [1])
check('جست‌وجوی شماره', [r['number'] for r in lst('all', num=2)] == [2])
check('فیلتر مشتری', [r['number'] for r in lst('all', party=1)] == [1])
check('فاکتور بدون طرف‌حساب نمایش داده می‌شود', lst('all')[0]['party_name'] == '')

print('-- کالا و موجودی')
items = {r['name']: r for r in q('qItemsList', '', '', A, A, 1, '', '', '')}
check('موجودی قلم = ۱۰۰ + ۵۰ − ۱۳٫۵ = ۱۳۶٫۵', items['قلم']['stock_milli'] == 136500, items['قلم']['stock_milli'])
check('نام دسته', items['قلم']['category_name'] == 'لوازم')
check('فیلتر نوع', [r['name'] for r in q('qItemsList', 'service', 'service', A, A, 1, '', '', '')] == ['تعمیر'])
check('موجودی بدون حرکات یک فاکتور', q('qStockExcludingInvoice', 1, i1)[0][0] == 136500 + 10000)

print('-- گزارش پرداخت‌ها')
pr = lambda m='', d='', party=A: q('qPaymentsReport', *R, party, party, m, m, d, d, 100)
check('همه پرداخت‌ها ۵ تا', len(pr()) == 5)
check('فیلتر روش pos', [r['amount'] for r in pr('pos')] == [28000])
check('فیلتر جهت out', [r['amount'] for r in pr('', 'out')] == [200000])
check('پرداخت عمومی (بدون فاکتور) دیده می‌شود', any(r['inv_number'] is None and r['amount'] == 7000 for r in pr()))
check('پرداخت‌های یک فاکتور', len(q('qPaymentsOf', A, A, i1, i1, 50)) == 1)

print('-- تریگرهای یکپارچگی')
check('پرداخت بیش از مبلغ فاکتور رد می‌شود', raises(db, "INSERT INTO payments(party_id,invoice_id,direction,method,amount,date,created_at) VALUES(1,?,'in','cash',45001,'2026-11-09',?)", (i1, NOW), 'overpay'))
ex("INSERT INTO payments(party_id,invoice_id,direction,method,amount,date,created_at) VALUES(1,?,'in','cash',45000,'2026-11-09',?)", (i1, NOW))
check('پرداخت دقیق باقی‌مانده مجاز است', q('qUnsettledSummary')[0]['cnt'] == 0)
check('جهت ناسازگار با نوع فاکتور رد می‌شود', raises(db, "INSERT INTO payments(party_id,invoice_id,direction,method,amount,date,created_at) VALUES(3,?,'in','cash',1,'2026-11-09',?)", (p1, NOW), 'direction_mismatch'))
check('طرف‌حساب ناسازگار رد می‌شود', raises(db, "INSERT INTO payments(party_id,invoice_id,direction,method,amount,date,created_at) VALUES(2,?,'out','cash',1,'2026-11-09',?)", (p1, NOW), 'party_mismatch'))
check('کاهش مبلغ فاکتور کمتر از پرداخت‌ها رد می‌شود', raises(db, "UPDATE invoices SET total=100000 WHERE id=?", (i1,), 'total_below_paid'))
check('حذف منطقی فاکتور دارای پرداخت رد می‌شود', raises(db, "UPDATE invoices SET deleted_at=? WHERE id=?", (NOW, i1), 'has_payments'))
check('پرداخت روی فاکتور حذف‌شده/ناموجود رد می‌شود', raises(db, "INSERT INTO payments(party_id,invoice_id,direction,method,amount,date,created_at) VALUES(1,9999,'in','cash',1,'2026-11-09',?)", (NOW,), 'invoice_not_found'))
# تخصیص پرداخت عمومی مریم (۷٬۰۰۰) به فاکتور ۲ که کامل پرداخت شده: رد
gid = db.execute("SELECT id FROM payments WHERE invoice_id IS NULL").fetchone()[0]
check('تخصیص پرداخت عمومی به فاکتور تسویه‌شده رد می‌شود', raises(db, "UPDATE payments SET invoice_id=? WHERE id=?", (i2, gid), 'overpay'))
# حذف منطقی پرداخت و سپس حذف فاکتور
ex("UPDATE payments SET deleted_at=? WHERE invoice_id=?", (NOW, i3)); ex("UPDATE invoices SET deleted_at=? WHERE id=?", (NOW, i3))
check('پس از حذف پرداخت‌ها، فاکتور قابل حذف منطقی است', db.execute("SELECT deleted_at FROM invoices WHERE id=?", (i3,)).fetchone()[0] is not None)
check('فاکتور حذف‌شده در فهرست و گزارش نیست', [r['number'] for r in lst('all')] == [2, 1] and sum(r['amount'] for r in q('qSalesByDay', *R, A, A, A, A)) == 173000)

print('-- قیدهای داده')
check('موبایل تکراری برای یک نوع رد می‌شود', raises(db, "INSERT INTO parties(code,kind,name,mobile,created_at) VALUES('C9','customer','x','09121111111',?)", (NOW,), 'UNIQUE'))
check('موبایل نامعتبر رد می‌شود', raises(db, "INSERT INTO parties(code,kind,name,mobile,created_at) VALUES('C8','customer','x','12345',?)", (NOW,), 'CHECK'))
check('کد تکراری رد می‌شود', raises(db, "INSERT INTO parties(code,kind,name,created_at) VALUES('C0001','customer','x',?)", (NOW,), 'UNIQUE'))
check('شماره فاکتور تکراری هم‌نوع رد می‌شود', raises(db, "INSERT INTO invoices(kind,number,date,total,created_at,updated_at) VALUES('sale',1,'2026-11-01',0,?,?)", (NOW, NOW), 'UNIQUE'))
check('قیمت منفی رد می‌شود', raises(db, "INSERT INTO items(code,kind,name,sale_price,created_at) VALUES('X','product','x',-1,?)", (NOW,), 'CHECK'))
check('تعداد صفر در ردیف فاکتور رد می‌شود', raises(db, "INSERT INTO invoice_items(invoice_id,title,item_kind,qty_milli,unit_price,line_total) VALUES(?, 'a','free',0,1,0)", (i1,), 'CHECK'))
check('پرداخت صفر/منفی رد می‌شود', raises(db, "INSERT INTO payments(party_id,direction,method,amount,date,created_at) VALUES(1,'in','cash',0,'2026-11-09',?)", (NOW,), 'CHECK'))
check('پرداخت بدون طرف‌حساب و فاکتور رد می‌شود', raises(db, "INSERT INTO payments(direction,method,amount,date,created_at) VALUES('in','cash',5,'2026-11-09',?)", (NOW,), 'CHECK'))
check('کلید خارجی: ردیف با فاکتور ناموجود رد می‌شود', raises(db, "INSERT INTO invoice_items(invoice_id,title,item_kind,qty_milli,unit_price,line_total) VALUES(9999,'a','free',1000,1,1)", (), 'FOREIGN'))
check('integrity_check سالم', db.execute('PRAGMA integrity_check').fetchone()[0] == 'ok')
check('foreign_key_check خالی', db.execute('PRAGMA foreign_key_check').fetchall() == [])

print(f'\n=> {passed} passed, {failed} failed'); sys.exit(1 if failed else 0)
