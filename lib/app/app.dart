import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../app_version.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/auth_pages.dart';
import '../features/shell/app_shell.dart';
import 'app_controller.dart';
import 'app_scope.dart';

class AccountingApp extends StatelessWidget {
  final AppController controller;
  const AccountingApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => AppScope(
    controller: controller,
    child: ListenableBuilder(
      listenable: controller,
      builder: (context, _) => MaterialApp(
        title: kAppName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: controller.themeMode,
        locale: const Locale('fa', 'IR'),
        supportedLocales: const [Locale('fa', 'IR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const _Gate(),
      ),
    ),
  );
}

class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return switch (c.phase) {
      AppPhase.booting => const SplashView(),
      AppPhase.checking => const SplashView(text: 'در حال بررسی اشتراک…'),
      AppPhase.configError => ConfigErrorPage(errors: c.configErrors),
      AppPhase.needLogin => const LoginPage(),
      AppPhase.offline => OfflinePage(message: c.message),
      AppPhase.blocked => const BlockedPage(),
      AppPhase.fatal => FatalPage(message: c.message ?? 'خطای نامشخص'),
      AppPhase.ready => const AppShell(),
    };
  }
}
