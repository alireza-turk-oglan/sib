import '../database.dart';

/// تنظیمات کسب‌وکار (داخل دیتابیس؛ همراه پشتیبان‌گیری می‌شود)
class SettingsRepo {
  final AppDatabase db;
  SettingsRepo(this.db);

  String get(String key, [String def = '']) =>
      (db.scalar('SELECT value FROM settings WHERE key=?', [key]) as String?) ??
      def;
  bool getBool(String key, [bool def = false]) {
    final v = get(key, def ? '1' : '0');
    return v == '1';
  }

  void set(String key, String value) => db.exec(
    'INSERT INTO settings(key, value) VALUES(?, ?) ON CONFLICT(key) DO UPDATE SET value=excluded.value',
    [key, value],
  );
  void setBool(String key, bool v) => set(key, v ? '1' : '0');

  bool get allowNegativeStock => getBool('allow_negative_stock');
  bool get updateCostOnPurchase => getBool('update_cost_on_purchase', true);
}
