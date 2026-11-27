import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'app/app.dart';
import 'app/app_controller.dart';
import 'app_version.dart';
import 'core/platform/app_log.dart';
import 'core/platform/app_paths.dart';
import 'core/platform/prefs_store.dart';

class _CloseHandler with WindowListener {
  final AppController controller;
  _CloseHandler(this.controller);

  @override
  void onWindowClose() async {
    try {
      controller.shutdown();
    } catch (e, st) {
      Log.error('shutdown failed', e, st);
    }
    await windowManager.destroy();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPaths.init();
  Log.prune();
  Log.info('app start v$kAppVersion');

  FlutterError.onError = (d) {
    Log.error('flutter error', d.exception, d.stack);
    FlutterError.presentError(d);
  };
  PlatformDispatcher.instance.onError = (e, st) {
    Log.error('uncaught error', e, st);
    return true;
  };

  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(1320, 820),
    minimumSize: Size(1000, 660),
    center: true,
    title: kAppName,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  await windowManager.setPreventClose(true);

  final controller = AppController(PrefsStore.load(AppPaths.prefsPath));
  windowManager.addListener(_CloseHandler(controller));
  runApp(AccountingApp(controller: controller));
  controller.start();
}
