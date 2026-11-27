import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_controller.dart';
import '../../app/app_scope.dart';
import '../../app_version.dart';
import '../../core/config/api_constants.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../services/api_client.dart';
import '../../services/file_service.dart';

/// صفحه‌ای با کارت وسط‌چین برای وضعیت‌های ورود/مسدودی
class _CenterCard extends StatelessWidget {
  final Widget child;
  final double width;
  const _CenterCard({required this.child, this.width = 440});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width),
          child: AppCard(padding: const EdgeInsets.all(28), child: child),
        ),
      ),
    ),
  );
}

class SplashView extends StatelessWidget {
  final String text;
  const SplashView({super.key, this.text = 'در حال آماده‌سازی…'});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 18),
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 14),
          Text(text, style: TextStyle(color: AppColors.muted(context))),
        ],
      ),
    ),
  );
}

class ConfigErrorPage extends StatelessWidget {
  final List<String> errors;
  const ConfigErrorPage({super.key, required this.errors});

  @override
  Widget build(BuildContext context) => _CenterCard(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.settings_suggest_outlined,
          size: 40,
          color: AppColors.negative(context),
        ),
        const SizedBox(height: 12),
        Text(
          'پیکربندی برنامه نامعتبر است',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        for (final e in errors)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('• $e'),
          ),
        const SizedBox(height: 10),
        Text(
          'این نسخه با فایل env نادرست ساخته شده است. با پشتیبانی تماس بگیرید.',
          style: TextStyle(color: AppColors.muted(context)),
        ),
      ],
    ),
  );
}

class FatalPage extends StatelessWidget {
  final String message;
  const FatalPage({super.key, required this.message});

  @override
  Widget build(BuildContext context) => _CenterCard(
    width: 520,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, size: 40, color: AppColors.negative(context)),
        const SizedBox(height: 12),
        Text(
          'خطا در راه‌اندازی',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        SelectableText(message),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('تلاش دوباره'),
          onPressed: () => context.app.checkSession(),
        ),
      ],
    ),
  );
}

/// اینترنت یا سرور در دسترس نیست: ورود ممکن نیست (طبق قوانین اشتراک)
class OfflinePage extends StatelessWidget {
  final String? message;
  const OfflinePage({super.key, this.message});

  @override
  Widget build(BuildContext context) => _CenterCard(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.wifi_off_rounded,
          size: 48,
          color: AppColors.warning(context),
        ),
        const SizedBox(height: 14),
        Text(
          'اتصال به سرور برقرار نشد',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Text(
          '${message ?? ''}\n\nبرای ورود به برنامه، در هر بار اجرا باید اتصال اینترنت برقرار باشد. '
          'پس از ورود، همه امکانات حسابداری بدون اینترنت کار می‌کنند.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted(context), height: 1.8),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('تلاش مجدد'),
          onPressed: () => context.app.checkSession(),
        ),
      ],
    ),
  );
}

class BlockedPage extends StatelessWidget {
  const BlockedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final sub = c.subscription;
    final (IconData icon, String title, String body) = switch (c.blockReason) {
      BlockReason.updateRequired => (
        Icons.system_update_alt,
        'نیاز به به‌روزرسانی',
        'نسخه فعلی برنامه (${faDigits(kAppVersion)}) دیگر پشتیبانی نمی‌شود. لطفاً نسخه ${faDigits(c.appInfo.minVersion)} یا بالاتر را نصب کنید.',
      ),
      BlockReason.blockedUser => (
        Icons.block,
        'حساب کاربری مسدود است',
        c.message ??
            'حساب شما توسط مدیر مسدود شده است. با پشتیبانی تماس بگیرید.',
      ),
      _ => (
        Icons.lock_clock_outlined,
        sub?.status == 'suspended'
            ? 'اشتراک متوقف شده است'
            : (sub?.status == 'none'
                  ? 'اشتراک فعالی ندارید'
                  : 'اشتراک شما به پایان رسیده است'),
        'برای ادامه کار با نرم‌افزار، اشتراک خود را در وب‌سایت خریداری یا تمدید کنید. اطلاعات حسابداری شما سالم است و پس از تمدید در دسترس خواهد بود.',
      ),
    };
    return _CenterCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.warning(context)),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted(context), height: 1.8),
          ),
          if (sub?.endsAt != null &&
              c.blockReason == BlockReason.subscription) ...[
            const SizedBox(height: 8),
            Text('تاریخ پایان: ${fmtJalali(sub!.endsAt!.toIso8601String())}'),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (c.blockReason == BlockReason.updateRequired &&
                  c.appInfo.downloadUrl.isNotEmpty)
                FilledButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('دانلود نسخه جدید'),
                  onPressed: () => FileService.openUrl(c.appInfo.downloadUrl),
                ),
              if (c.blockReason == BlockReason.subscription)
                FilledButton.icon(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  label: const Text('خرید / تمدید اشتراک'),
                  onPressed: () =>
                      FileService.openUrl(AppConfig.sitePage('buy').toString()),
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('بررسی مجدد'),
                onPressed: () => c.checkSession(),
              ),
              TextButton(
                onPressed: () => c.logout(),
                child: const Text('خروج از حساب'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _codeStep = false;
  bool _busy = false;
  String? _error;
  bool _notRegistered = false;
  int _resend = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _startTimer(int secs) {
    _timer?.cancel();
    setState(() => _resend = secs);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resend = _resend > 0 ? _resend - 1 : 0);
      if (_resend == 0) t.cancel();
    });
  }

  Future<void> _sendCode() async {
    final phone = normalizeMobile(_phone.text);
    if (phone == null) {
      setState(() {
        _error = 'شماره موبایل معتبر نیست (فرمت صحیح: 09xxxxxxxxx).';
        _notRegistered = false;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notRegistered = false;
    });
    try {
      final t = await context.app.auth.requestOtp(phone);
      if (!mounted) return;
      _phone.text = phone;
      setState(() => _codeStep = true);
      _startTimer(t.resendAfterSeconds);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _notRegistered = e.code == ApiErrorCodes.notRegistered;
      });
      final w = (e.body?['wait'] as num?)?.toInt();
      if (w != null && w > 0 && w <= 120) _startTimer(w);
      if (e.code == ApiErrorCodes.blocked) await context.app.handleApiError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final code = enDigits(_code.text.trim());
    if (code.length != OtpRules.length) {
      setState(
        () =>
            _error = 'کد تأیید ${faDigits(OtpRules.length)} رقمی را وارد کنید.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final app = context.app;
    try {
      final r = await app.auth.verifyOtp(_phone.text, code);
      app.onLoginSuccess(r);
    } on ApiException catch (e) {
      if (e.code == ApiErrorCodes.subscriptionInactive ||
          e.code == ApiErrorCodes.blocked) {
        await app.handleApiError(e);
      } else if (mounted) {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final notice = c.message;
    return _CenterCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 10),
          Text(
            kAppName,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'ورود با شماره موبایل',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted(context)),
          ),
          const SizedBox(height: 20),
          if (notice != null && !_codeStep)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                notice,
                style: TextStyle(color: AppColors.warning(context)),
                textAlign: TextAlign.center,
              ),
            ),
          if (!_codeStep) ...[
            TextField(
              controller: _phone,
              autofocus: true,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              inputFormatters: [LengthLimitingTextInputFormatter(14)],
              decoration: deco(
                'شماره موبایل',
                hint: '09123456789',
                dense: false,
              ),
              onSubmitted: (_) => _busy ? null : _sendCode(),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _busy ? null : _sendCode,
              child: _busy ? const _Spinner() : const Text('ارسال کد تأیید'),
            ),
          ] else ...[
            Text(
              'کد ارسال‌شده به ${faDigits(_phone.text)} را وارد کنید.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              autofocus: true,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, letterSpacing: 6),
              inputFormatters: [
                LengthLimitingTextInputFormatter(OtpRules.length + 2),
              ],
              decoration: deco('کد تأیید', dense: false),
              onSubmitted: (_) => _busy ? null : _verify(),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _busy ? null : _verify,
              child: _busy ? const _Spinner() : const Text('ورود'),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: (_busy || _resend > 0) ? null : _sendCode,
                  child: Text(
                    _resend > 0
                        ? 'ارسال مجدد (${faDigits(_resend)})'
                        : 'ارسال مجدد کد',
                  ),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _codeStep = false;
                          _code.clear();
                          _error = null;
                        }),
                  child: const Text('تغییر شماره'),
                ),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.negative(context)),
            ),
          ],
          if (_notRegistered) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('ثبت‌نام در وب‌سایت'),
              onPressed: () => FileService.openUrl(
                AppConfig.sitePage('register').toString(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'نسخه ${faDigits(kAppVersion)}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
          ),
        ],
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 20,
    height: 20,
    child: CircularProgressIndicator(strokeWidth: 2.5),
  );
}
