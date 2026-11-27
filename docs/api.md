# مستندات API نرم‌افزار ویندوز

پایه: `https://دامنه/api/v1/` — همه درخواست‌ها `POST` و بدنه JSON. پاسخ موفق `{"ok":true,...}` و خطا `{"ok":false,"code":"...","message":"فارسی"}`.
هدر احراز هویت (به‌جز OTP): `Authorization: Bearer <token>` و در بدنه `device_id` (۱۶ تا ۶۴ کاراکتر `[A-Za-z0-9_-]`).

| مسیر | بدنه | توضیح |
|---|---|---|
| `auth/otp/request` | `phone`, `device_id` | ارسال OTP به کاربر ثبت‌نام‌شده. پاسخ: `ttl`, `resend_after`. خطاها: `not_registered`(404) `blocked`(403) `bad_phone`(422) `otp_failed`(429) |
| `auth/otp/verify` | `phone`, `code`, `device_id`, `device_name` | پاسخ: `token`, `expires_at`, `subscription`, `app`, `server_time`. خطاها: `bad_code`(401) `subscription_inactive`(402، با `subscription`/`app` در بدنه) `device_limit`(409) |
| `auth/check` | `device_id` | هر بار اجرای برنامه. موفق: `subscription`, `app`. خطاها: `token_invalid` `device_mismatch`(401) `blocked`(403) `subscription_inactive`(402) |
| `auth/logout` | `device_id` | ابطال توکن |
| `sms/send` | `device_id`, `message`, `recipients[]` | پیامک باشگاه (حداکثر ۵۰۰ گیرنده در هر درخواست). پاسخ: `sent`, `failed`, `results[{phone,status,error}]`. خطاها: `daily_limit`(429) `sms_disabled`(403) `subscription_inactive`(402) |

`user`: `{phone, name}` در پاسخ `auth/otp/verify` و `auth/check`؛ `name` نام و نام خانوادگی ثبت‌شده در سایت است و برای کاربران قدیمی ممکن است `null` باشد (برنامه در این حالت شماره را نشان می‌دهد).
`subscription`: `{status: active|expired|none|suspended|blocked, type: trial|free|paid, ends_at (ISO), days_left}`.
`app`: `{latest_version, min_version, download_url}`؛ اگر نسخه برنامه از `min_version` کمتر باشد ورود مسدود می‌شود.

## قوانین
- OTP: ۶ رقم، اعتبار ۱۲۰ ثانیه، فاصله ارسال مجدد ۶۰ ثانیه، حداکثر ۵ تلاش.
- یک اشتراک = یک دستگاه؛ تغییر دستگاه حداکثر N بار در ۳۰ روز (پیش‌فرض ۳، از تنظیمات).
- هیچ داده حسابداری به سرور نمی‌رود؛ فقط شماره موبایل، شناسه دستگاه و متن/گیرندگان پیامک.
