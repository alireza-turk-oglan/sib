<?php
// نمونه تنظیمات. فایل install.php این فایل را به‌صورت خودکار با نام config.php می‌سازد.
// این فایل باید بیرون از public_html قرار بگیرد.
return [
    'db_host'    => 'localhost',
    'db_name'    => 'DB_NAME',
    'db_user'    => 'DB_USER',
    'db_pass'    => 'DB_PASSWORD',
    'site_url'   => 'https://example.com',   // بدون اسلش پایانی
    'app_key'    => 'RANDOM_64_HEX_CHARS',   // کلید رمزنگاری کلیدهای API در دیتابیس؛ پس از ساخت تغییر ندهید
    'timezone'   => 'Asia/Tehran',
    'ip_header'  => null,                    // پشت Cloudflare: 'HTTP_CF_CONNECTING_IP'
    'debug'      => false,
    // فقط برای تست؛ در محیط واقعی تغییر ندهید:
    // 'ippanel_base' => 'https://edge.ippanel.com/v1',
    // 'zarinpal_api' => 'https://payment.zarinpal.com',
    // 'zarinpal_pay' => 'https://www.zarinpal.com',
    // 'zibal_base'   => 'https://gateway.zibal.ir',
];
