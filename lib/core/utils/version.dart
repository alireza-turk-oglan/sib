/// مقایسه نسخه‌های «۱.۲.۳». منفی: a<b ، صفر: برابر ، مثبت: a>b
int compareVersions(String a, String b) {
  List<int> parse(String s) =>
      s.split(RegExp(r'[.+\-]')).map((e) => int.tryParse(e) ?? 0).toList();
  final x = parse(a);
  final y = parse(b);
  final n = x.length > y.length ? x.length : y.length;
  for (var i = 0; i < n; i++) {
    final p = i < x.length ? x[i] : 0;
    final q = i < y.length ? y[i] : 0;
    if (p != q) return p < q ? -1 : 1;
  }
  return 0;
}
