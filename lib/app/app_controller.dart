import 'dart:io';

import 'package:flutter/material.dart';

import '../app_version.dart';
import '../core/config/api_constants.dart';
import '../core/config/app_config.dart';
import '../core/platform/app_log.dart';
import '../core/platform/app_paths.dart';
import '../core/platform/prefs_store.dart';
import '../core/utils/version.dart';
import '../domain/business_profile.dart';
import '../data/backup_service.dart';
import '../data/database.dart';
import '../data/repos/invoices_repo.dart';
import '../data/repos/items_repo.dart';
import '../data/repos/parties_repo.dart';
import '../data/repos/payments_repo.dart';
import '../data/repos/reports_repo.dart';
import '../data/repos/settings_repo.dart';
import '../data/repos/sms_repo.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/secure_store.dart';

/// مجموعه Repositoryها روی یک دیتابیس باز. UI فقط از همین‌ها استفاده می‌کند.
class AppServices {
  final AppDatabase db;
  final SettingsRepo settings;
  final PartiesRepo parties;
  final ItemsRepo items;
  final InvoicesRepo invoices;
  final PaymentsRepo payments;
  final ReportsRepo reports;
  final SmsRepo sms;
  final List<String> startupIssues;

  AppServices._(this.db, this.settings, this.parties, this.items, this.invoices, this.payments, this.reports, this.sms, this.startupIssues);

  static AppServices open(String path) {
    final db = AppDatabase.open(path);
    final settings = SettingsRepo(db);
    return AppServices._(db, settings, PartiesRepo(db), ItemsRepo(db), InvoicesRepo(db, settings), PaymentsRepo(db), ReportsRepo(db), SmsRepo(db), db.healthIssues());
  }
}

enum AppPhase { booting, configError, checking, needLogin, offline, blocked, fatal, ready }

enum BlockReason { subscription, blockedUser, updateRequired }

class AppController extends ChangeNotifier {
  final PrefsStore prefs;
  final ApiClient api;
  final SecureStore secure;
  late final AuthService auth = AuthService(api, secure);

  AppPhase phase = AppPhase.booting;
  BlockReason? blockReason;
  String? message;
  List<String> configErrors = const [];
  SubscriptionInfo? subscription;
  AppInfo appInfo = const AppInfo();
  String phone = '';
  String userName = '';
  AppServices? services;
  ThemeMode themeMode = ThemeMode.system;

  /// نام و لوگوی کسب‌وکار (بالای منوی کناری)
  BusinessProfile profile = const BusinessProfile.empty();

  /// با هر بازیابی/تغییر بزرگ داده افزایش می‌یابد تا صفحه‌ها دوباره بارگذاری شوند
  int dataVersion = 0;

  AppController(this.prefs, {ApiClient? apiClient, SecureStore? secureStore})
      : api = apiClient ?? ApiClient(),
        secure = secureStore ?? SecureStore() {
    themeMode = switch (prefs.getString('theme')) { 'light' => ThemeMode.light, 'dark' => ThemeMode.dark, _ => ThemeMode.system };
  }

  void _set(AppPhase p, {String? msg}) {
    phase = p;
    message = msg;
    notifyListeners();
  }

  Future<void> start() async {
    final errs = AppConfig.validate();
    if (errs.isNotEmpty) {
      configErrors = errs;
      _set(AppPhase.configError);
      return;
    }
    await checkSession();
  }

  Future<void> checkSession() async {
    _set(AppPhase.checking);
    try {
      final r = await auth.check();
      if (r == null) {
        _set(AppPhase.needLogin);
        return;
      }
      _applyAuth(r);
    } on ApiException catch (e) {
      await handleApiError(e);
    } catch (e, st) {
      Log.error('checkSession failed', e, st);
      _set(AppPhase.offline, msg: 'خطای غیرمنتظره در بررسی اشتراک.');
    }
  }

  /// پس از ورود موفق با OTP
  void onLoginSuccess(AuthResult r) => _applyAuth(r);

  /// نام نمایشی کاربر؛ اگر هنوز نامی ثبت نکرده، شماره موبایل
  String get displayName => userName.trim().isNotEmpty ? userName.trim() : phone;

  void _applyAuth(AuthResult r) {
    userName = r.name;
    subscription = r.subscription;
    appInfo = r.app;
    phone = r.phone;
    if (r.app.minVersion.isNotEmpty && compareVersions(kAppVersion, r.app.minVersion) < 0) {
      blockReason = BlockReason.updateRequired;
      _set(AppPhase.blocked);
      return;
    }
    if (!r.subscription.isActive) {
      blockReason = r.subscription.status == 'blocked' ? BlockReason.blockedUser : BlockReason.subscription;
      _set(AppPhase.blocked);
      return;
    }
    try {
      services ??= AppServices.open(AppPaths.dbPath);
      profile = BusinessProfile.fromSettings(services!.settings);
    } catch (e, st) {
      Log.error('database open failed', e, st);
      _set(AppPhase.fatal, msg: e is DomainError ? e.message : 'باز کردن پایگاه داده ممکن نشد. از پشتیبان بازیابی کنید یا با پشتیبانی تماس بگیرید.\n$e');
      return;
    }
    _set(AppPhase.ready);
  }

  /// تفسیر خطای سرور در بررسی/ورود
  Future<void> handleApiError(ApiException e) async {
    switch (e.code) {
      case ApiErrorCodes.tokenInvalid:
      case ApiErrorCodes.deviceMismatch:
        await secure.clearToken();
        _set(AppPhase.needLogin, msg: e.message);
      case ApiErrorCodes.subscriptionInactive:
        subscription = SubscriptionInfo.fromJson(e.body?['subscription'] as Map<String, dynamic>?);
        appInfo = AppInfo.fromJson(e.body?['app'] as Map<String, dynamic>?);
        blockReason = BlockReason.subscription;
        _set(AppPhase.blocked);
      case ApiErrorCodes.blocked:
        blockReason = BlockReason.blockedUser;
        _set(AppPhase.blocked, msg: e.message);
      default:
        _set(AppPhase.offline, msg: e.message);
    }
  }

  /// بررسی دوباره اشتراک در حین کار (بدون بیرون‌انداختن کاربر در صورت قطع اینترنت). پیام خطا یا null.
  Future<String?> refreshSubscription() async {
    try {
      final r = await auth.check();
      if (r == null) {
        await checkSession();
        return null;
      }
      subscription = r.subscription;
      appInfo = r.app;
      if (r.name.isNotEmpty) userName = r.name;
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      const definitive = {ApiErrorCodes.tokenInvalid, ApiErrorCodes.deviceMismatch, ApiErrorCodes.subscriptionInactive, ApiErrorCodes.blocked};
      if (definitive.contains(e.code)) await handleApiError(e);
      return e.message;
    }
  }

  Future<void> logout() async {
    await auth.logout();
    _closeServices();
    subscription = null;
    userName = '';
    _set(AppPhase.needLogin);
  }

  void _closeServices() {
    try {
      services?.db.close();
    } catch (_) {}
    services = null;
    profile = const BusinessProfile.empty();
  }

  // ---- ظاهر ----
  void setThemeMode(ThemeMode m) {
    themeMode = m;
    prefs.setString('theme', m == ThemeMode.light ? 'light' : (m == ThemeMode.dark ? 'dark' : 'system'));
    notifyListeners();
  }

  void reloadData() {
    dataVersion++;
    reloadProfile(notify: false);
    notifyListeners();
  }

  /// خواندن دوباره نام/لوگو از تنظیمات (پس از ذخیره در تنظیمات یا بازیابی پشتیبان)
  void reloadProfile({bool notify = true}) {
    final s = services;
    profile = s == null ? const BusinessProfile.empty() : BusinessProfile.fromSettings(s.settings);
    if (notify) notifyListeners();
  }

  // ---- پشتیبان ----
  String get backupDir => prefs.getString('backup_dir') ?? AppPaths.defaultBackupDir;
  bool get autoBackup => prefs.getBool('auto_backup', true);

  /// بازیابی از فایل پشتیبان؛ پس از موفقیت دیتابیس جدید باز و همه صفحات بارگذاری مجدد می‌شوند.
  void restoreFrom(String backupPath) {
    final s = services;
    if (s == null) throw DomainError('ابتدا وارد شوید.');
    try {
      BackupService.restore(backupPath: backupPath, current: s.db, safetyDir: AppPaths.safetyDir, appVersion: kAppVersion);
    } finally {
      // در هر حالت (موفق یا ناموفق) دیتابیس دوباره باز می‌شود تا برنامه روی داده معتبر بماند
      if (s.db.isClosed) services = AppServices.open(AppPaths.dbPath);
    }
    reloadData();
  }

  /// پشتیبان خودکار هنگام خروج و بستن امن دیتابیس
  void shutdown() {
    final s = services;
    if (s == null) return;
    try {
      if (autoBackup) {
        BackupService.create(s.db, AppPaths.autoBackupDir, appVersion: kAppVersion, prefix: 'sib-auto');
        BackupService.prune(AppPaths.autoBackupDir, keep: 7);
      }
    } catch (e, st) {
      Log.error('auto backup on exit failed', e, st);
    }
    _closeServices();
    api.close();
  }

  String get dataFolder => File(AppPaths.dbPath).parent.path;
}
