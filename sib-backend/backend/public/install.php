<?php
declare(strict_types=1);
// نصب‌کننده یک‌بارمصرف. پس از نصب این فایل را از سرور حذف کنید.
define('APP_ROOT', dirname(__DIR__));
require __DIR__ . '/../app/core.php';
header('Content-Type: text/html; charset=utf-8');
header('X-Robots-Tag: noindex');
rebase_output();

$lock = APP_ROOT . '/storage/install.lock';
function shell(string $body): never {
    echo '<!doctype html><html lang="fa" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>نصب</title><link rel="stylesheet" href="/assets/style.css"></head><body><main class="wrap"><div class="card narrow" style="max-width:520px">' . $body . '</div></main></body></html>';
    exit;
}
if (is_file($lock)) { http_response_code(403); shell('<h1>نصب انجام شده است</h1><p>فایل <b>install.php</b> را از سرور حذف کنید.</p>'); }

$msg = ''; $v = ['db_host' => 'localhost', 'db_name' => '', 'db_user' => '', 'site_url' => (is_https_i() ? 'https://' : 'http://') . ($_SERVER['HTTP_HOST'] ?? '') . base_path(), 'admin_user' => 'admin'];
function is_https_i(): bool { return !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off'; }

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
    foreach (['db_host', 'db_name', 'db_user', 'site_url', 'admin_user'] as $k) $v[$k] = trim((string)($_POST[$k] ?? ''));
    $dbPass = (string)($_POST['db_pass'] ?? ''); $adminPass = (string)($_POST['admin_pass'] ?? '');
    try {
        if (!preg_match('#^https?://[^\s]*[^/\s]$#', $v['site_url'])) throw new RuntimeException('آدرس سایت باید مثل https://example.com باشد (بدون اسلش پایانی؛ در زیرپوشه مثلاً http://localhost/sib/public).');
        if (!preg_match('/^[A-Za-z0-9_.]{3,40}$/', $v['admin_user'])) throw new RuntimeException('نام کاربری مدیر نامعتبر است.');
        if (mb_strlen($adminPass) < 10) throw new RuntimeException('رمز مدیر باید حداقل ۱۰ کاراکتر باشد.');
        foreach (['openssl', 'curl', 'mbstring', 'pdo_mysql'] as $ext) if (!extension_loaded($ext)) throw new RuntimeException("افزونه PHP «$ext» فعال نیست.");
        if (!preg_match('/^[A-Za-z0-9_]{1,64}$/', $v['db_name'])) throw new RuntimeException('نام دیتابیس فقط می‌تواند شامل حروف لاتین، عدد و _ باشد.');
        $opt = [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION];
        try {
            $pdo = new PDO("mysql:host={$v['db_host']};dbname={$v['db_name']};charset=utf8mb4", $v['db_user'], $dbPass, $opt);
        } catch (PDOException $ex) {
            if ((int)$ex->getCode() !== 1049) throw $ex;   // دیتابیس وجود ندارد: در لوکال خودکار ساخته می‌شود
            $root = new PDO("mysql:host={$v['db_host']};charset=utf8mb4", $v['db_user'], $dbPass, $opt);
            $root->exec('CREATE DATABASE `' . $v['db_name'] . '` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');
            $pdo = new PDO("mysql:host={$v['db_host']};dbname={$v['db_name']};charset=utf8mb4", $v['db_user'], $dbPass, $opt);
        }
        $sql = file_get_contents(APP_ROOT . '/schema.sql');
        foreach (array_filter(array_map('trim', explode(';', (string)$sql))) as $stmt) $pdo->exec($stmt);
        $key = bin2hex(random_bytes(32));
        $cfg = "<?php\nreturn " . var_export([
            'db_host' => $v['db_host'], 'db_name' => $v['db_name'], 'db_user' => $v['db_user'], 'db_pass' => $dbPass,
            'site_url' => $v['site_url'], 'app_key' => $key, 'timezone' => 'Asia/Tehran', 'ip_header' => null, 'debug' => false,
        ], true) . ";\n";
        if (file_put_contents(APP_ROOT . '/config.php', $cfg, LOCK_EX) === false) throw new RuntimeException('نوشتن config.php ممکن نیست؛ دسترسی پوشه را بررسی کنید.');
        @chmod(APP_ROOT . '/config.php', 0600);
        $pdo->prepare('INSERT INTO admins(username,password_hash,role,created_at) VALUES(?,?,?,?)')
            ->execute([$v['admin_user'], password_hash($adminPass, PASSWORD_DEFAULT), 'super', gmdate('Y-m-d H:i:s')]);
        if (!is_dir(dirname($lock))) mkdir(dirname($lock), 0750, true);
        file_put_contents($lock, gmdate('c'));
        shell('<h1>نصب کامل شد</h1><p>ورود به <a href="/admin">پنل مدیریت</a>، سپس در بخش «تنظیمات» اطلاعات IPPanel و درگاه‌ها را وارد کنید و پلن بسازید.</p><div class="alert err">اکنون فایل <b>install.php</b> را از سرور حذف کنید.</div>');
    } catch (Throwable $e) {
        $msg = '<div class="alert err">' . e($e instanceof PDOException ? 'خطای دیتابیس: ' . $e->getMessage() : $e->getMessage()) . '</div>';
    }
}
$in = fn(string $n, string $l, string $t = 'text', bool $req = true) => '<label>' . $l . '</label><input name="' . $n . '" type="' . $t . '" dir="ltr" value="' . ($t === 'password' ? '' : e($v[$n] ?? '')) . '"' . ($req ? ' required' : '') . '>';
shell('<h1>نصب سیستم اشتراک</h1>' . $msg . '<form method="post">' . $in('db_host', 'میزبان دیتابیس') . $in('db_name', 'نام دیتابیس') . $in('db_user', 'کاربر دیتابیس') . $in('db_pass', 'رمز دیتابیس (در نصب لوکال اغلب خالی است)', 'password', false)
    . $in('site_url', 'آدرس سایت') . $in('admin_user', 'نام کاربری مدیر') . $in('admin_pass', 'رمز مدیر (حداقل ۱۰ کاراکتر)', 'password') . '<button class="btn">نصب</button></form>');
