# راهنمای نصب سرور (وب‌سایت + پنل + API)

Backend با PHP ساده و MariaDB است (بدون Laravel). حداقل: PHP 8.1+ با افزونه‌های `pdo_mysql`, `curl`, `mbstring`, `openssl`.

## الف) هاست cPanel
1. در cPanel یک دیتابیس MariaDB و یک کاربر با دسترسی کامل بسازید.
2. ساختار آپلود (کنار `public_html`، نه داخل آن):
```
/home/USER/
  app/            ← پوشه app
  storage/        ← پوشه storage (قابل نوشتن)
  schema.sql
  public_html/    ← محتوای پوشه public (index.php, api.php, admin.php, install.php, assets, .htaccess)
```
3. آدرس `https://دامنه/install.php` را باز کنید؛ اطلاعات دیتابیس، آدرس سایت (بدون اسلش پایانی) و نام کاربری/رمز مدیر را وارد کنید. نصب‌کننده جدول‌ها را می‌سازد، `config.php` (دسترسی ۶۰۰) را کنار `app` می‌نویسد و خودش را قفل می‌کند.
4. **فایل `install.php` را از سرور حذف کنید.**
5. به `https://دامنه/admin` بروید و در «تنظیمات»: IPPanel، درگاه‌ها و اشتراک آزمایشی را تنظیم و در «پلن‌ها» پلن بسازید.
6. SSL (https) الزامی است؛ نرم‌افزار ویندوز در نسخه نهایی فقط https را می‌پذیرد.

## ب) لوکال (XAMPP/PHP داخلی)
- ساده‌ترین راه: `run-local.bat` در پوشه backend، سپس `http://localhost:8000/install.php`. رمز دیتابیس می‌تواند خالی باشد و دیتابیس خودکار ساخته می‌شود.
- اگر با Apache در زیرپوشه کار می‌کنید (مثلاً `localhost/sib/public`)، `site_url` را با همان مسیر بگذارید. `mod_rewrite` و `AllowOverride All` لازم است.

## نکات امنیتی
- `config.php` و `storage/` باید بیرون از وب باشند. کلیدهای API در دیتابیس با AES-256-GCM رمز می‌شوند (کلید در `config.php`؛ پس از نصب تغییر ندهید و از آن پشتیبان بگیرید).
- لاگ خطاها: `storage/logs`. پشتیبان‌گیری دیتابیس سرور از طریق cPanel/phpMyAdmin انجام شود.
