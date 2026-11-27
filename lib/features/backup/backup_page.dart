import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app_version.dart';
import '../../core/platform/app_paths.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../data/backup_service.dart';
import '../../services/file_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  List<BackupFileEntry> files = [];
  String lastBackup = '';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    if (!mounted) return;
    setState(() {
      lastBackup = context.svc.settings.get('last_backup_at');
      files = BackupService.list(context.app.backupDir);
    });
  }

  Future<void> _chooseFolder() async {
    final app = context.app;
    final dir = await FileService.pickDirectory('انتخاب پوشه ذخیره پشتیبان');
    if (dir == null || !mounted) return;
    try {
      Directory(dir).createSync(recursive: true);
      final probe = File('$dir${Platform.pathSeparator}.write-test');
      probe.writeAsStringSync('ok');
      probe.deleteSync();
    } catch (_) {
      if (mounted) {
        toast(
          context,
          'نوشتن در این پوشه ممکن نیست. پوشه دیگری انتخاب کنید.',
          error: true,
        );
      }
      return;
    }
    app.prefs.setString('backup_dir', dir);
    _load();
  }

  Future<void> _create() async {
    final app = context.app;
    final s = context.svc;
    setState(() => busy = true);
    final info = tryValue(
      context,
      () => BackupService.create(
        s.db,
        app.backupDir,
        appVersion: kAppVersion,
        settings: s.settings,
      ),
    );
    if (mounted) setState(() => busy = false);
    if (info != null && mounted) {
      toast(context, 'پشتیبان ساخته و اعتبارسنجی شد: ${info.path}');
      _load();
    }
  }

  Future<void> _restore(String path) async {
    final info = tryValue(context, () => BackupService.inspect(path));
    if (info == null || !mounted) return;
    final m = info.meta;
    final c = m.counts;
    final ok = await confirmDialog(
      context,
      title: 'بازیابی پشتیبان',
      message:
          'فایل: ${path.split(RegExp(r'[\\/]')).last}\n'
          'تاریخ تهیه: ${fmtJalaliDateTime(m.createdAt)}\n'
          'محتوا: ${faDigits(c['customers'] ?? 0)} مشتری، ${faDigits(c['items'] ?? 0)} کالا/خدمت، ${faDigits(c['invoices'] ?? 0)} فاکتور، ${faDigits(c['payments'] ?? 0)} پرداخت\n\n'
          'اطلاعات فعلی با این پشتیبان جایگزین می‌شود. پیش از آن یک نسخه ایمنی از وضعیت فعلی به‌طور خودکار ساخته می‌شود. ادامه می‌دهید؟',
      confirmLabel: 'بازیابی',
      danger: true,
    );
    if (!ok || !mounted) return;
    final app = context.app;
    setState(() => busy = true);
    final done = tryRun(context, () => app.restoreFrom(path));
    if (!mounted) return;
    setState(() => busy = false);
    if (done) {
      toast(context, 'بازیابی با موفقیت انجام شد.');
      _load();
    }
  }

  Future<void> _pickAndRestore() async {
    final p = await FileService.pickBackupFile();
    if (p != null && mounted) await _restore(p);
  }

  void _health() {
    final issues = tryValue(context, () => context.svc.db.healthIssues());
    if (issues == null || !mounted) return;
    if (issues.isEmpty) {
      messageDialog(
        context,
        'سلامت پایگاه داده',
        'پایگاه داده سالم است و هیچ ناسازگاری‌ای پیدا نشد.',
      );
    } else {
      messageDialog(
        context,
        'مشکل در پایگاه داده',
        'موارد زیر پیدا شد. توصیه می‌شود از آخرین پشتیبان سالم بازیابی کنید:\n\n${issues.map((e) => '• $e').join('\n')}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          const PageHeader(
            title: 'پشتیبان‌گیری و بازیابی',
            subtitle:
                'اطلاعات حسابداری فقط روی همین کامپیوتر نگهداری می‌شود؛ پشتیبان منظم بگیرید',
          ),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              SizedBox(
                width: 420,
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'آخرین پشتیبان‌گیری',
                        style: TextStyle(color: AppColors.muted(context)),
                      ),
                      Text(
                        lastBackup.isEmpty
                            ? 'هنوز پشتیبان نگرفته‌اید'
                            : fmtJalaliDateTime(lastBackup),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: lastBackup.isEmpty
                              ? AppColors.warning(context)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'پوشه ذخیره',
                        style: TextStyle(color: AppColors.muted(context)),
                      ),
                      SelectableText(
                        app.backupDir,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: busy ? null : _create,
                            icon: const Icon(Icons.backup_outlined),
                            label: const Text('تهیه پشتیبان'),
                          ),
                          OutlinedButton.icon(
                            onPressed: busy ? null : _chooseFolder,
                            icon: const Icon(Icons.folder_open_outlined),
                            label: const Text('تغییر پوشه'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                FileService.openPath(app.backupDir),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('باز کردن پوشه'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 420,
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'بازیابی و سلامت',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: busy ? null : _pickAndRestore,
                            icon: const Icon(Icons.restore),
                            label: const Text('بازیابی از فایل…'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _health,
                            icon: const Icon(Icons.health_and_safety_outlined),
                            label: const Text('بررسی سلامت پایگاه داده'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('پشتیبان خودکار هنگام خروج'),
                        subtitle: const Text('۷ نسخه آخر نگه داشته می‌شود.'),
                        value: app.autoBackup,
                        onChanged: (v) {
                          app.prefs.setBool('auto_backup', v);
                          setState(() {});
                        },
                      ),
                      Text(
                        'پشتیبان ایمنی قبل از هر بازیابی در پوشه برنامه ساخته می‌شود:',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted(context),
                        ),
                      ),
                      SelectableText(
                        AppPaths.safetyDir,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SectionTitle('پشتیبان‌های موجود در پوشه'),
          if (files.isEmpty)
            const AppCard(
              child: EmptyState(
                icon: Icons.inventory_outlined,
                text: 'پشتیبانی در این پوشه پیدا نشد.',
              ),
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final f in files.take(30))
                    ListTile(
                      dense: true,
                      title: Text(
                        f.name,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.end,
                      ),
                      subtitle: Text(
                        '${fmtJalaliDateTime(f.modified.toUtc().toIso8601String())} • ${faDigits((f.size / 1024).round())} کیلوبایت',
                      ),
                      trailing: TextButton.icon(
                        onPressed: busy ? null : () => _restore(f.path),
                        icon: const Icon(Icons.restore),
                        label: const Text('بازیابی'),
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
