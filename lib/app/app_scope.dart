import 'package:flutter/widgets.dart';

import 'app_controller.dart';

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(s != null, 'AppScope not found');
    return s!.notifier!;
  }

  /// بدون ثبت وابستگی (برای رویدادها)
  static AppController read(BuildContext context) =>
      (context.getInheritedWidgetOfExactType<AppScope>())!.notifier!;
}

extension AppContext on BuildContext {
  AppController get app => AppScope.read(this);
  AppServices get svc => AppScope.read(this).services!;
}
