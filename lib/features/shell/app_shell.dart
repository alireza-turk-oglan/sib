import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../app_version.dart';
import '../../core/utils/format.dart';
import '../../domain/business_profile.dart';
import '../../services/file_service.dart';
import '../backup/backup_page.dart';
import '../club/club_page.dart';
import '../customers/customers_page.dart';
import '../dashboard/dashboard_page.dart';
import '../invoices/invoices_page.dart';
import '../items/items_page.dart';
import '../payments/payments_page.dart';
import '../reports/reports_page.dart';
import '../settings/settings_page.dart';
import 'account_dialog.dart';

class _Nav {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const _Nav(this.label, this.icon, this.selectedIcon);
}

const _navs = [
  _Nav('داشبورد', Icons.dashboard_outlined, Icons.dashboard),
  _Nav('مشتریان', Icons.people_outline, Icons.people),
  _Nav('کالا و خدمات', Icons.inventory_2_outlined, Icons.inventory_2),
  _Nav('فاکتورها', Icons.receipt_long_outlined, Icons.receipt_long),
  _Nav('پرداخت‌ها', Icons.payments_outlined, Icons.payments),
  _Nav('باشگاه مشتریان', Icons.campaign_outlined, Icons.campaign),
  _Nav('گزارش‌ها', Icons.bar_chart_outlined, Icons.bar_chart),
  _Nav('پشتیبان‌گیری', Icons.backup_outlined, Icons.backup),
  _Nav('تنظیمات', Icons.settings_outlined, Icons.settings),
];

/// قاب اصلی: منوی کناری (در RTL سمت راست) + محتوا. در عرض کم منو به آیکون جمع می‌شود.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  Widget _page(int i) => switch (i) {
        0 => DashboardPage(onNavigate: (x) => setState(() => index = x)),
        1 => const CustomersPage(),
        2 => const ItemsPage(),
        3 => const InvoicesPage(),
        4 => const PaymentsPage(),
        5 => const ClubPage(),
        6 => const ReportsPage(),
        7 => const BackupPage(),
        _ => const SettingsPage(),
      };

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final sub = app.subscription;
    final issues = app.services?.startupIssues ?? const <String>[];
    final soon = sub != null && sub.isActive && sub.daysLeft <= 7;
    return Scaffold(
      body: Column(children: [
        if (issues.isNotEmpty)
          _Banner(
            color: AppColors.negative(context),
            icon: Icons.error_outline,
            text: 'بررسی سلامت پایگاه داده مشکل پیدا کرد (${issues.first}). توصیه می‌شود از بخش «پشتیبان‌گیری» از آخرین نسخه سالم بازیابی کنید.',
          ),
        if (soon)
          _Banner(
            color: AppColors.warning(context),
            icon: Icons.schedule,
            text: 'اشتراک شما ${faDigits(sub.daysLeft)} روز دیگر به پایان می‌رسد.',
            action: TextButton(onPressed: () => FileService.openUrl(AppConfig.sitePage('buy').toString()), child: const Text('تمدید اشتراک')),
          ),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            final wide = box.maxWidth >= 1180;
            return Row(children: [
              NavigationRail(
                extended: wide,
                minExtendedWidth: 190,
                selectedIndex: index,
                onDestinationSelected: (i) => setState(() => index = i),
                labelType: NavigationRailLabelType.none, // با ۹ بخش، حالت فشرده فقط آیکون (با راهنما) تا در پنجره کوچک سرریز نشود
                leading: _RailBrand(profile: app.profile, extended: wide),
                trailingAtBottom: true,
                trailing: Padding(padding: const EdgeInsets.only(bottom: 14), child: _AccountButton(extended: wide)),
                destinations: [
                  for (final n in _navs)
                    NavigationRailDestination(
                      icon: Tooltip(message: n.label, child: Icon(n.icon)),
                      selectedIcon: Tooltip(message: n.label, child: Icon(n.selectedIcon)),
                      label: Text(n.label),
                    ),
                ],
              ),
              VerticalDivider(width: 1, color: AppColors.line(context)),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: KeyedSubtree(key: ValueKey('$index-${app.dataVersion}'), child: _page(index)),
                ),
              ),
            ]);
          }),
        ),
      ]),
    );
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  final Widget? action;
  const _Banner({required this.color, required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) => Container(
        color: color.withAlpha(30),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(children: [Icon(icon, size: 18, color: color), const SizedBox(width: 8), Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13))), ?action]),
      );
}

/// بالای منوی کناری: لوگوی اختیاری + نام کسب‌وکار (اگر لوگو یا نام تعریف نشده باشد، آیکون پیش‌فرض)
class _RailBrand extends StatelessWidget {
  final BusinessProfile profile;
  final bool extended;
  const _RailBrand({required this.profile, required this.extended});

  Widget _mark(BuildContext context, double size) {
    final cs = Theme.of(context).colorScheme;
    final fallback = Icon(Icons.account_balance_wallet_outlined, color: cs.primary, size: size * 0.6);
    final logo = profile.logo;
    if (logo == null) return SizedBox(width: size, height: size, child: Center(child: fallback));
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.memory(
        logo,
        width: size,
        height: size,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => SizedBox(width: size, height: size, child: Center(child: fallback)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = profile.displayName;
    if (!extended) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Tooltip(message: name.isEmpty ? kAppName : name, child: _mark(context, 44)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
      child: SizedBox(
        width: 170,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _mark(context, 60),
          if (name.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.4)),
          ],
        ]),
      ),
    );
  }
}

/// دکمه حساب کاربری پایین منوی کناری: نام کاربر و وضعیت اشتراک؛ با کلیک جزئیات اشتراک نمایش داده می‌شود
class _AccountButton extends StatelessWidget {
  final bool extended;
  const _AccountButton({required this.extended});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final sub = app.subscription;
    final cs = Theme.of(context).colorScheme;
    final color = subscriptionColor(context, sub);
    final name = app.displayName;
    final avatar = CircleAvatar(
      radius: extended ? 18 : 20,
      backgroundColor: cs.primaryContainer,
      child: Text(avatarInitial(name), style: TextStyle(fontWeight: FontWeight.w700, color: cs.onPrimaryContainer)),
    );
    final status = sub == null
        ? ''
        : (sub.isActive ? 'اشتراک ${subscriptionStatusLabel(sub)} • ${faDigits(sub.daysLeft)} روز' : 'اشتراک ${subscriptionStatusLabel(sub)}');
    final radius = BorderRadius.circular(14);
    return InkWell(
      borderRadius: radius,
      onTap: () => showAccountDialog(context),
      child: extended
          ? Container(
              width: 176,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(borderRadius: radius, border: Border.all(color: AppColors.line(context))),
              child: Row(children: [
                avatar,
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ]),
            )
          : Tooltip(message: '$name\n$status', child: Padding(padding: const EdgeInsets.all(6), child: avatar)),
    );
  }
}
