@echo off
chcp 65001 >nul
if not exist env\prod.json (
  echo فایل env\prod.json وجود ندارد. از env\prod.json.example کپی کنید و آدرس دامنه را بگذارید.
  exit /b 1
)
flutter build windows --release --dart-define-from-file=env/prod.json --obfuscate --split-debug-info=build/symbols
