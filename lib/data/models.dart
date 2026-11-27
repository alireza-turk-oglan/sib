import '../domain/invoice_calc.dart';

class Party {
  final int id;
  final String code;
  final String kind; // customer | supplier
  final String name;
  final String? mobile;
  final String? description;
  final bool smsConsent;
  final bool isActive;
  final String createdAt;
  final int totalAmount; // جمع فاکتورها
  final int paidAmount; // جمع دریافتی/پرداختی
  const Party({
    required this.id,
    required this.code,
    required this.kind,
    required this.name,
    this.mobile,
    this.description,
    required this.smsConsent,
    required this.isActive,
    required this.createdAt,
    this.totalAmount = 0,
    this.paidAmount = 0,
  });

  /// مثبت: بدهکار (مشتری به ما بدهکار است / ما به تأمین‌کننده بدهکاریم) ، منفی: بستانکار
  int get balance => totalAmount - paidAmount;
  bool get isCustomer => kind == 'customer';

  factory Party.fromRow(Map<String, Object?> r) => Party(
    id: r['id'] as int,
    code: r['code'] as String,
    kind: r['kind'] as String,
    name: r['name'] as String,
    mobile: r['mobile'] as String?,
    description: r['description'] as String?,
    smsConsent: (r['sms_consent'] as int) == 1,
    isActive: (r['is_active'] as int) == 1,
    createdAt: r['created_at'] as String,
    totalAmount: (r['total_amount'] as int?) ?? 0,
    paidAmount: (r['paid_amount'] as int?) ?? 0,
  );
}

class Category {
  final int id;
  final String name;
  final String kind;
  const Category(this.id, this.name, this.kind);
}

class Item {
  final int id;
  final String code;
  final String kind; // product | service
  final String name;
  final int? categoryId;
  final String? categoryName;
  final String? description;
  final int salePrice;
  final int purchasePrice;
  final bool trackStock;
  final int minStockMilli;
  final bool isActive;
  final int stockMilli;
  const Item({
    required this.id,
    required this.code,
    required this.kind,
    required this.name,
    this.categoryId,
    this.categoryName,
    this.description,
    required this.salePrice,
    required this.purchasePrice,
    required this.trackStock,
    this.minStockMilli = 0,
    required this.isActive,
    this.stockMilli = 0,
  });
  bool get isProduct => kind == 'product';
  double get stock => stockMilli / 1000.0;
  bool get lowStock => isProduct && trackStock && stockMilli <= minStockMilli;

  factory Item.fromRow(Map<String, Object?> r) => Item(
    id: r['id'] as int,
    code: r['code'] as String,
    kind: r['kind'] as String,
    name: r['name'] as String,
    categoryId: r['category_id'] as int?,
    categoryName: r['category_name'] as String?,
    description: r['description'] as String?,
    salePrice: r['sale_price'] as int,
    purchasePrice: r['purchase_price'] as int,
    trackStock: (r['track_stock'] as int) == 1,
    minStockMilli: (r['min_stock_milli'] as int?) ?? 0,
    isActive: (r['is_active'] as int) == 1,
    stockMilli: (r['stock_milli'] as int?) ?? 0,
  );
}

class InvoiceSummary {
  final int id;
  final String kind; // sale | purchase
  final int number;
  final String date;
  final int total;
  final int? partyId;
  final String partyName;
  final String? description;
  final int paid;
  const InvoiceSummary({
    required this.id,
    required this.kind,
    required this.number,
    required this.date,
    required this.total,
    this.partyId,
    required this.partyName,
    this.description,
    required this.paid,
  });
  int get remaining => total - paid;
  PayStatus get status => payStatus(total, paid);
  bool get isSale => kind == 'sale';

  factory InvoiceSummary.fromRow(Map<String, Object?> r) => InvoiceSummary(
    id: r['id'] as int,
    kind: r['kind'] as String,
    number: r['number'] as int,
    date: r['date'] as String,
    total: r['total'] as int,
    partyId: r['party_id'] as int?,
    partyName: (r['party_name'] as String?) ?? '',
    description: r['description'] as String?,
    paid: (r['paid'] as int?) ?? 0,
  );
}

class InvoiceLine {
  final int id;
  final int? itemId;
  final String title;
  final String itemKind; // product | service | free
  final int qtyMilli;
  final int unitPrice;
  final int discount;
  final int lineTotal;
  final int costUnit;
  const InvoiceLine({
    required this.id,
    this.itemId,
    required this.title,
    required this.itemKind,
    required this.qtyMilli,
    required this.unitPrice,
    required this.discount,
    required this.lineTotal,
    required this.costUnit,
  });
  double get qty => qtyMilli / 1000.0;
  factory InvoiceLine.fromRow(Map<String, Object?> r) => InvoiceLine(
    id: r['id'] as int,
    itemId: r['item_id'] as int?,
    title: r['title'] as String,
    itemKind: r['item_kind'] as String,
    qtyMilli: r['qty_milli'] as int,
    unitPrice: r['unit_price'] as int,
    discount: r['discount'] as int,
    lineTotal: r['line_total'] as int,
    costUnit: r['cost_unit'] as int,
  );
}

class InvoiceDetail {
  final InvoiceSummary summary;
  final List<InvoiceLine> lines;
  final List<PaymentRow> payments;
  const InvoiceDetail(this.summary, this.lines, this.payments);
}

class PaymentRow {
  final int id;
  final int? invoiceId;
  final int? partyId;
  final String direction; // in | out
  final String method; // cash | card_transfer | pos
  final int amount;
  final String date;
  final String description;
  final int? invNumber;
  const PaymentRow({
    required this.id,
    this.invoiceId,
    this.partyId,
    required this.direction,
    required this.method,
    required this.amount,
    required this.date,
    required this.description,
    this.invNumber,
  });
  factory PaymentRow.fromRow(Map<String, Object?> r) => PaymentRow(
    id: r['id'] as int,
    invoiceId: r['invoice_id'] as int?,
    partyId: r['party_id'] as int?,
    direction: r['direction'] as String,
    method: r['method'] as String,
    amount: r['amount'] as int,
    date: r['date'] as String,
    description: (r['description'] as String?) ?? '',
    invNumber: r['inv_number'] as int?,
  );
}

const Map<String, String> kMethodLabels = {
  'cash': 'نقدی',
  'card_transfer': 'کارت‌به‌کارت',
  'pos': 'کارت‌خوان',
};

/// پیش‌نویس فاکتور برای ذخیره
class InvoiceDraft {
  final int? id;
  final String kind;
  final int? partyId;
  final String? partyName; // برای فروش/خرید متفرقه بدون طرف‌حساب ثبت‌شده
  final String date; // ISO
  final String description;
  final List<LineInput> lines;
  const InvoiceDraft({
    this.id,
    required this.kind,
    this.partyId,
    this.partyName,
    required this.date,
    this.description = '',
    required this.lines,
  });
}

class SmsLogRow {
  final int id;
  final int? partyId;
  final String name;
  final String mobile;
  final String message;
  final String kind;
  final String status;
  final String? error;
  final String batchId;
  final String createdAt;
  const SmsLogRow({
    required this.id,
    this.partyId,
    required this.name,
    required this.mobile,
    required this.message,
    required this.kind,
    required this.status,
    this.error,
    required this.batchId,
    required this.createdAt,
  });
  factory SmsLogRow.fromRow(Map<String, Object?> r) => SmsLogRow(
    id: r['id'] as int,
    partyId: r['party_id'] as int?,
    name: (r['name'] as String?) ?? '',
    mobile: r['mobile'] as String,
    message: r['message'] as String,
    kind: r['kind'] as String,
    status: r['status'] as String,
    error: r['error'] as String?,
    batchId: r['batch_id'] as String,
    createdAt: r['created_at'] as String,
  );
}
