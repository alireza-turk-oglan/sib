@echo off
chcp 65001 >nul
flutter pub get
flutter analyze
flutter test
