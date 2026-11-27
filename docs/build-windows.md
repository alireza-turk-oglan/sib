# Build نسخه نهایی ویندوز

## پیش‌نیاز
Flutter 3.44 (Windows desktop فعال) و Visual Studio 2022 با workload «Desktop development with C++». اگر `flutter_secure_storage` هنگام Build خطای ATL داد، کامپوننت **C++ ATL** را از Visual Studio Installer اضافه کنید. بسته `sqlite3` در اولین Build کتابخانه SQLite آماده را دانلود می‌کند (اینترنت لازم است).

## قبل از Build
1. `windows/runner/Runner.rc`: مقدار `CompanyName` و `ProductName` را به نام خودتان تغییر دهید؛ پوشه اطلاعات کاربر `%APPDATA%\<CompanyName>\<ProductName>\data\accounting.db` از همین‌ها ساخته می‌شود (پیش‌فرض `com.example` مناسب انتشار نیست).
2. نسخه را هم در `pubspec.yaml` و هم در `lib/app_version.dart` یکسان تغییر دهید.
3. `env/prod.json.example` را کپی کنید به `env/prod.json` و آدرس https دامنه را بگذارید. `use_arabic=true` را حذف نکنید (اتصال حروف فارسی در PDF).

## Build
`scripts\build_release.bat` ← خروجی: `build\windows\x64\runner\Release\`. برای عیب‌یابی Crash، پوشه `build\symbols` را نگه دارید (عمومی نکنید). اگر `--obfuscate` خطا داد از اسکریپت حذفش کنید.

## نصب‌کننده
کل پوشه `Release` را با Inno Setup بسته‌بندی کنید. نکات الزامی: داده‌ها در `%APPDATA%` هستند، پس **در بخش Uninstall هرگز پوشه داده را حذف نکنید** (یا فقط با پرسش صریح از کاربر).

## تست دستی قبل از انتشار
ورود با OTP؛ قطع اینترنت و اجرای دوباره (ورود باید رد شود)؛ ورود و سپس قطع اینترنت (برنامه باید کار کند)؛ ثبت فاکتور و پرداخت؛ پشتیبان → تغییر → بازیابی؛ تغییر اندازه پنجره تا حداقل ۱۰۰۰×۶۶۰؛ تم تاریک؛ چاپ/PDF فارسی.
