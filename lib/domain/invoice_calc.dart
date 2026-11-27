/// محاسبات مالی فاکتور. همه مبالغ عدد صحیح (تومان) هستند؛ هیچ ممیز شناوری در جمع‌ها نیست.
const int kMaxQty = 99999;
const int kMaxPrice = 10000000000; // ۱۰ میلیارد تومان برای هر واحد

/// مقدار را به ۳ رقم اعشار گرد می‌کند و به «هزارم» (عدد صحیح) برمی‌گرداند.
int qtyMilli(double qty) => (qty * 1000).round();

/// جمع ردیف = round(تعداد × قیمت واحد) − تخفیف  (گرد کردن نیم‌به‌بالا، با ریاضی صحیح)
int lineGross(double qty, int unitPrice) =>
    (qtyMilli(qty) * unitPrice + 500) ~/ 1000;

int lineTotal(double qty, int unitPrice, int discount) =>
    lineGross(qty, unitPrice) - discount;

/// پیام خطا یا null اگر معتبر
String? validateLine({
  required String title,
  required double qty,
  required int unitPrice,
  required int discount,
}) {
  if (title.trim().isEmpty) return 'عنوان ردیف خالی است.';
  if (qty.isNaN || qty <= 0) return 'تعداد باید بیشتر از صفر باشد.';
  if (qty > kMaxQty) return 'تعداد بیش از حد مجاز است.';
  if (qtyMilli(qty) <= 0) return 'تعداد بسیار کوچک است.';
  if (unitPrice < 0) return 'قیمت واحد نمی‌تواند منفی باشد.';
  if (unitPrice > kMaxPrice) return 'قیمت واحد بیش از حد مجاز است.';
  if (discount < 0) return 'تخفیف نمی‌تواند منفی باشد.';
  if (discount > lineGross(qty, unitPrice)) {
    return 'تخفیف از مبلغ ردیف بیشتر است.';
  }
  return null;
}

enum PayStatus { unpaid, partial, paid }

int remainingOf(int total, int paid) => total - paid;

PayStatus payStatus(int total, int paid) {
  if (paid <= 0) return total <= 0 ? PayStatus.paid : PayStatus.unpaid;
  if (paid >= total) return PayStatus.paid;
  return PayStatus.partial;
}

String payStatusLabel(PayStatus s) => switch (s) {
  PayStatus.unpaid => 'پرداخت‌نشده',
  PayStatus.partial => 'پرداخت جزئی',
  PayStatus.paid => 'تسویه‌شده',
};

/// ورودی یک ردیف فاکتور (برای ذخیره)
class LineInput {
  final int? itemId; // null = ردیف آزاد (مثلاً هزینه)
  final String title;
  final double qty;
  final int unitPrice;
  final int discount;
  const LineInput({
    this.itemId,
    required this.title,
    required this.qty,
    required this.unitPrice,
    this.discount = 0,
  });

  int get total => lineTotal(qty, unitPrice, discount);
}

int sumLines(Iterable<LineInput> lines) => lines.fold(0, (s, l) => s + l.total);
