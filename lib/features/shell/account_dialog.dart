import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/utils/jalali.dart';
import '../../core/widgets/common.dart';
import '../../services/api_client.dart';
import '../../services/file_service.dart';

/// حرف اول نام برای آواتار (یا رقم اول شماره)
String avatarInitial(String s) {
  final t = s.trim();
  return t.isEmpty ? '؟' : String.fromCharCode(t.runes.first);
}

String subscriptionStatusLabel(SubscriptionInfo? s) => switch (s?.status) {
      'active' => 'فعال',
      'expired' => 'منقضی‌شده',
      'suspended' => 'متوقف',
      'blocked' => 'مسدود',
      _ => 'بدون اشتراک',
    };

Color subscriptionColor(BuildContext c, SubscriptionInfo? s) {
  if (s == null || !s.isActive) return AppColors.negative(c);
  return s.daysLeft <= 7 ? AppColors.warning(c) : AppColors.positive(c);
}

/// منوی حساب کاربری: نام، موبایل، وضعیت/نوع/تاریخ پایان اشتراک، تمدید و خروج
Future<void> showAccountDialog(BuildContext context) => showDialog<void>(context: context, builder: (_) => const _AccountDialog());

class _AccountDialog extends StatefulWidget {
  const _AccountDialog();

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  bool checking = false;

  Future<void> _refresh() async {
    final app = context.app;
    setState(() => checking = true);
    final msg = await app.refreshSubscription();
    if (!mounted) return;
    setState(() => checking = false);
    toast(context, msg ?? 'اشتراک بررسی شد.', error: msg != null);
  }

  Future<void> _logout() async {
    final app = context.app;
    final ok = await confirmDialog(context, title: 'خروج از حساب', message: 'از حساب خارج می‌شوید. اطلاعات حسابداری روی این کامپیوتر حفظ می‌شود. برای ورود دوباره به اینترنت نیاز است.', confirmLabel: 'خروج');
    if (!ok || !mounted) return;
    Navigator.pop(context);
    await app.logout();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final sub = app.subscription;
    final color = subscriptionColor(context, sub);
    final cs = Theme.of(context).colorScheme;
    final end = sub?.endsAt;
    return AppDialog(
      title: 'حساب کاربری',
      width: 440,
      actions: [
        TextButton(onPressed: _logout, style: TextButton.styleFrom(foregroundColor: cs.error), child: const Text('خروج از حساب')),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('بستن')),
      ],
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          CircleAvatar(radius: 28, backgroundColor: cs.primaryContainer, child: Text(avatarInitial(app.displayName), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: cs.onPrimaryContainer))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(app.displayName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (app.userName.isNotEmpty) Text(faDigits(app.phone), textDirection: TextDirection.ltr, style: TextStyle(color: AppColors.muted(context))),
              if (app.userName.isEmpty) Text('نامی ثبت نشده؛ از پنل کاربری سایت اضافه کنید.', style: TextStyle(fontSize: 12, color: AppColors.muted(context))),
            ]),
          ),
        ]),
        const Divider(height: 28),
        _row(context, 'وضعیت اشتراک', StatusChip(subscriptionStatusLabel(sub), color)),
        _row(context, 'نوع اشتراک', Text(sub?.typeLabel ?? '—', style: const TextStyle(fontWeight: FontWeight.w600))),
        _row(context, 'تاریخ پایان', Text(end == null ? '—' : fmtJalaliLong(isoDate(end)), style: const TextStyle(fontWeight: FontWeight.w600))),
        _row(context, 'روز باقی‌مانده', Text(sub != null && sub.isActive ? faDigits(sub.daysLeft) : '—', style: TextStyle(fontWeight: FontWeight.w800, color: color))),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(onPressed: () => FileService.openUrl(AppConfig.sitePage('buy').toString()), icon: const Icon(Icons.shopping_cart_outlined), label: const Text('خرید / تمدید اشتراک')),
          OutlinedButton.icon(onPressed: checking ? null : _refresh, icon: checking ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh), label: const Text('بررسی دوباره')),
          OutlinedButton.icon(onPressed: () => FileService.openUrl(AppConfig.sitePage('panel').toString()), icon: const Icon(Icons.open_in_new), label: const Text('پنل کاربری سایت')),
        ]),
      ]),
    );
  }

  Widget _row(BuildContext context, String k, Widget v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [SizedBox(width: 120, child: Text(k, style: TextStyle(color: AppColors.muted(context)))), Expanded(child: Align(alignment: AlignmentDirectional.centerStart, child: v))]),
      );
}
