import 'package:flutter/material.dart';

import '../../data/backup_format.dart';
import '../../data/database.dart';
import '../platform/app_log.dart';
import '../theme/app_theme.dart';

void toast(BuildContext context, String msg, {bool error = false}) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  final cs = Theme.of(context).colorScheme;
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      content: Text(
        msg,
        style: TextStyle(color: error ? cs.onError : cs.onInverseSurface),
      ),
      backgroundColor: error ? cs.error : cs.inverseSurface,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: error ? 6 : 3),
    ),
  );
}

/// اجرای یک عملیات دیتابیسی با نمایش پیام فارسی برای خطاها. true = موفق
bool tryRun(BuildContext context, void Function() action) {
  try {
    action();
    return true;
  } on DomainError catch (e) {
    toast(context, e.message, error: true);
  } on BackupFormatException catch (e) {
    toast(context, e.message, error: true);
  } catch (e, st) {
    Log.error('unexpected error', e, st);
    toast(
      context,
      'خطای غیرمنتظره رخ داد. جزئیات در گزارش خطا ثبت شد.',
      error: true,
    );
  }
  return false;
}

/// مثل tryRun ولی مقدار برمی‌گرداند (null در صورت خطا)
T? tryValue<T>(BuildContext context, T Function() action) {
  T? out;
  final ok = tryRun(context, () => out = action());
  return ok ? out : null;
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'تأیید',
  bool danger = false,
}) async {
  final cs = Theme.of(context).colorScheme;
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('انصراف'),
        ),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(
                  backgroundColor: cs.error,
                  foregroundColor: cs.onError,
                )
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return r ?? false;
}

Future<void> messageDialog(
  BuildContext context,
  String title,
  String message,
) => showDialog<void>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: Text(title),
    content: Text(message),
    actions: [
      FilledButton(
        onPressed: () => Navigator.pop(ctx),
        child: const Text('باشه'),
      ),
    ],
  ),
);

/// دیالوگ استاندارد با عرض مشخص و محتوای اسکرول‌شونده
class AppDialog extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;
  final double width;
  const AppDialog({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.width = 480,
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(title),
    scrollable: true,
    content: SizedBox(width: width, child: child),
    actions: actions,
  );
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Material(
      color: AppColors.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: AppColors.line(context)),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final String? subtitle;
  final VoidCallback? onTap;
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: c),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.muted(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.muted(context),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(color: AppColors.muted(context)),
                ),
            ],
          ),
        ),
        ...actions.expand((a) => [const SizedBox(width: 8), a]),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.muted(context)),
          const SizedBox(height: 10),
          Text(
            text,
            style: TextStyle(color: AppColors.muted(context)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class StatusChip extends StatelessWidget {
  final String text;
  final Color color;
  const StatusChip(this.text, this.color, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    decoration: BoxDecoration(
      color: color.withAlpha(36),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
    ),
  );
}

/// فیلد انتخابی (جایگزین DropdownButtonFormField که API آن در نسخه‌های Flutter تغییر کرده است)
class DropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  const DropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: deco(label),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        isExpanded: true,
        isDense: true,
      ),
    ),
  );
}

InputDecoration deco(
  String label, {
  String? hint,
  Widget? suffix,
  String? suffixText,
  bool dense = true,
}) => InputDecoration(
  labelText: label,
  hintText: hint,
  suffixIcon: suffix,
  suffixText: suffixText,
  isDense: dense,
  border: const OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(10)),
  ),
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
);

String? requiredValidator(String? v, [String msg = 'این فیلد الزامی است.']) =>
    (v == null || v.trim().isEmpty) ? msg : null;

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 8),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}
