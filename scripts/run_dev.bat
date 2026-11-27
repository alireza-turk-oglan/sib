@echo off
chcp 65001 >nul
flutter run -d windows --dart-define-from-file=env/dev.json
