import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app_version.dart';
import '../../core/config/app_config.dart';
import '../../core/platform/app_paths.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../data/database.dart' show DomainError;
import '../../services/logo_service.dart';
import '../../domain/business_profile.dart';
import '../../services/file_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _footer = TextEditingController();
  bool negative = false;
  bool updateCost = true;
  bool checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = context.svc.settings;
      setState(() {
        _name.text = s.get('business_name');
        _phone.text = s.get('business_phone');
        _address.text = s.get('business_address');
        _footer.text = s.get('invoice_footer');
        negative = s.allowNegativeStock;
        updateCost = s.updateCostOnPurchase;
      });
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _footer]) {
      c.dispose();
    }
    super.dispose();
  }

  void _saveBusiness() {
    final s = context.svc.settings;
    final ok = tryRun(context, () {
      s.set('business_name', _name.text.trim());
      s.set('business_phone', _phone.text.trim());
      s.set('business_address', _address.text.trim());
      s.set('invoice_footer', _footer.text.trim());
    });
    if (ok) {
      context.app.reloadProfile();
      toast(context, 'اطلاعات ذخیره شد.');
    }
  }

  Future<void> _pickLogo() async {
    final app = context.app;
    final path = await FileService.pickImage();
    if (path == null || !mounted) return;
    try {
      final png = await LogoService.prepare(path);
      if (!mounted) return;
      if (tryRun(context, () => app.services!.settings.set(BusinessProfile.logoKey, BusinessProfile.encodeLogo(png)))) {
        app.reloadProfile();
        toast(context, 'لوگو ذخیره شد.');
      }
    } on DomainError catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (_) {
      if (mounted) toast(context, 'خواندن تصویر ممکن نشد. فایل دیگری را امتحان کنید.', error: true);
    }
  }

  void _removeLogo() {
    final app = context.app;
    if (tryRun(context, () => app.services!.settings.set(BusinessProfile.logoKey, ''))) {
      app.reloadProfile();
      toast(context, 'لوگو حذف شد.');
    }
  }

  Future<void> _refreshSub() async {
    final app = context.app;
    setState(() => checking = true);
    final msg = await app.refreshSubscription();
    if (!mounted) return;
    setState(() => checking = false);
    toast(context, msg ?? 'اشتراک بررسی شد.', error: msg != null);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final sub = app.subscription;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(children: [
        const PageHeader(title: 'تنظیمات'),
        Wrap(spacing: 14, runSpacing: 14, crossAxisAlignment: WrapCrossAlignment.start, children: [
          _card(context, 'ظاهر برنامه', [
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('خودکار'), icon: Icon(Icons.brightness_auto)),
                ButtonSegment(value: ThemeMode.light, label: Text('روشن'), icon: Icon(Icons.light_mode_outlined)),
                ButtonSegment(value: ThemeMode.dark, label: Text('تاریک'), icon: Icon(Icons.dark_mode_outlined)),
              ],
              selected: {app.themeMode},
              onSelectionChanged: (s) => app.setThemeMode(s.first),
            ),
            const SizedBox(height: 6),
            Text('انتخاب شما ذخیره می‌شود و پس از اجرای مجدد حفظ می‌شود.', style: TextStyle(fontSize: 12, color: AppColors.muted(context))),
          ]),
          _card(context, 'حساب کاربری و اشتراک', [
            _kv('نام', app.userName.isEmpty ? 'ثبت نشده (از پنل کاربری سایت وارد کنید)' : app.userName),
            _kv('شماره موبایل', faDigits(app.phone)),
            _kv('وضعیت اشتراک', sub == null ? '—' : (sub.isActive ? 'فعال' : sub.status)),
            _kv('نوع اشتراک', sub?.typeLabel ?? '—'),
            _kv('تاریخ پایان', sub?.endsAt == null ? '—' : fmtJalali(sub!.endsAt!.toIso8601String())),
            _kv('روز باقی‌مانده', sub == null ? '—' : faDigits(sub.daysLeft)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(onPressed: () => FileService.openUrl(AppConfig.sitePage('buy').toString()), icon: const Icon(Icons.shopping_cart_outlined), label: const Text('خرید / تمدید اشتراک')),
              OutlinedButton.icon(onPressed: checking ? null : _refreshSub, icon: const Icon(Icons.refresh), label: const Text('بررسی دوباره')),
              TextButton(
                onPressed: () async {
                  if (await confirmDialog(context, title: 'خروج از حساب', message: 'از حساب خارج می‌شوید. اطلاعات حسابداری روی این کامپیوتر حفظ می‌شود. برای ورود دوباره به اینترنت نیاز است.', confirmLabel: 'خروج')) {
                    await app.logout();
                  }
                },
                child: const Text('خروج از حساب'),
              ),
            ]),
          ]),
        ]),
        const SizedBox(height: 14),
        _card(context, 'اطلاعات کسب‌وکار (نام و لوگو بالای منو، نام روی فاکتور)', [
          Row(children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(border: Border.all(color: AppColors.line(context)), borderRadius: BorderRadius.circular(14)),
              clipBehavior: Clip.antiAlias,
              child: app.profile.logo == null
                  ? Icon(Icons.image_outlined, color: AppColors.muted(context), size: 30)
                  : Image.memory(app.profile.logo!, fit: BoxFit.contain, gaplessPlayback: true, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('لوگوی کسب‌وکار (اختیاری)', style: TextStyle(color: AppColors.muted(context))),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  OutlinedButton.icon(onPressed: _pickLogo, icon: const Icon(Icons.upload_file_outlined), label: Text(app.profile.hasLogo ? 'تغییر لوگو' : 'انتخاب لوگو')),
                  if (app.profile.hasLogo) TextButton(onPressed: _removeLogo, child: const Text('حذف لوگو')),
                ]),
                const SizedBox(height: 4),
                Text('PNG یا JPG؛ به‌طور خودکار کوچک می‌شود و همراه پشتیبان ذخیره می‌شود.', style: TextStyle(fontSize: 11.5, color: AppColors.muted(context))),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          TextField(controller: _name, decoration: deco('نام کسب‌وکار')),
          const SizedBox(height: 10),
          TextField(controller: _phone, textDirection: TextDirection.ltr, decoration: deco('تلفن')),
          const SizedBox(height: 10),
          TextField(controller: _address, maxLines: 2, decoration: deco('نشانی')),
          const SizedBox(height: 10),
          TextField(controller: _footer, maxLines: 2, decoration: deco('متن پایین فاکتور (مثلاً شرایط گارانتی)')),
          const SizedBox(height: 12),
          Align(alignment: AlignmentDirectional.centerStart, child: FilledButton(onPressed: _saveBusiness, child: const Text('ذخیره'))),
        ], width: 640),
        const SizedBox(height: 14),
        Wrap(spacing: 14, runSpacing: 14, crossAxisAlignment: WrapCrossAlignment.start, children: [
          _card(context, 'موجودی و قیمت‌گذاری', [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('اجازه فروش بیش از موجودی'),
              subtitle: const Text('در حالت خاموش، فروش بیشتر از موجودی انبار رد می‌شود.'),
              value: negative,
              onChanged: (v) {
                setState(() => negative = v);
                tryRun(context, () => context.svc.settings.setBool('allow_negative_stock', v));
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('به‌روزرسانی قیمت خرید با فاکتور خرید'),
              subtitle: const Text('بهای تمام‌شده بر اساس آخرین قیمت خرید محاسبه می‌شود.'),
              value: updateCost,
              onChanged: (v) {
                setState(() => updateCost = v);
                tryRun(context, () => context.svc.settings.setBool('update_cost_on_purchase', v));
              },
            ),
          ]),
          _card(context, 'فایل‌ها و نسخه', [
            _kv('نسخه برنامه', faDigits(kAppVersion)),
            const SizedBox(height: 6),
            Text('پوشه اطلاعات حسابداری', style: TextStyle(fontSize: 12, color: AppColors.muted(context))),
            SelectableText(app.dataFolder, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              OutlinedButton(onPressed: () => FileService.openPath(app.dataFolder), child: const Text('باز کردن پوشه داده‌ها')),
              OutlinedButton(onPressed: () => FileService.openPath(AppPaths.logsDir), child: const Text('گزارش خطاها')),
            ]),
          ]),
        ]),
      ]),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [SizedBox(width: 130, child: Text(k, style: TextStyle(color: AppColors.muted(context)))), Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600)))]),
      );

  Widget _card(BuildContext context, String title, List<Widget> children, {double width = 420}) => SizedBox(
        width: width,
        child: AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 10), ...children])),
      );
}
