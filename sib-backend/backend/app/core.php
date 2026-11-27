<?php
declare(strict_types=1);

if (!defined('APP_ROOT')) define('APP_ROOT', dirname(__DIR__));
mb_internal_encoding('UTF-8');
date_default_timezone_set('UTC');

/* ---------- تنظیمات ---------- */
function cfg(string $k, mixed $d = null): mixed {
    static $c = null;
    if ($c === null) { $f = APP_ROOT . '/config.php'; $c = is_file($f) ? (require $f) : []; }
    return $c[$k] ?? $d;
}

/* ---------- لاگ و خطا ---------- */
function app_log(string $level, string $msg, array $ctx = []): void {
    $dir = APP_ROOT . '/storage/logs';
    if (!is_dir($dir)) @mkdir($dir, 0750, true);
    $line = gmdate('c') . " [$level] $msg" . ($ctx ? ' ' . json_encode($ctx, JSON_UNESCAPED_UNICODE) : '') . "\n";
    @file_put_contents("$dir/app-" . gmdate('Y-m-d') . '.log', $line, FILE_APPEND | LOCK_EX);
}

/* ---------- پایگاه داده ---------- */
function db(): PDO {
    static $p = null;
    if (!$p) {
        $p = new PDO(
            sprintf('mysql:host=%s;dbname=%s;charset=utf8mb4', cfg('db_host', 'localhost'), cfg('db_name')),
            (string)cfg('db_user'), (string)cfg('db_pass'),
            [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]
        );
        $p->exec("SET time_zone='+00:00'");
        migrate_if_needed($p);
    }
    return $p;
}

/** مهاجرت خودکار ساختار دیتابیس برای نصب‌های قدیمی (نسخه ۲: ستون full_name در users) */
function migrate_if_needed(PDO $p): void {
    static $done = false;
    if ($done) return;
    $done = true;
    try {
        $v = (int)$p->query("SELECT v FROM settings WHERE k='schema_version'")->fetchColumn();
    } catch (Throwable $e) {
        return;   // جدول settings هنوز وجود ندارد (پیش از نصب)
    }
    if ($v >= 2) return;
    try {
        $has = (int)$p->query("SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'full_name'")->fetchColumn();
        if (!$has) $p->exec('ALTER TABLE users ADD COLUMN full_name VARCHAR(100) NULL AFTER phone');
    } catch (Throwable $e) {
        // درخواست هم‌زمان دیگری ستون را اضافه کرده است
    }
    $p->exec("INSERT INTO settings(k, v, updated_at) VALUES('schema_version', '2', UTC_TIMESTAMP()) ON DUPLICATE KEY UPDATE v = '2', updated_at = UTC_TIMESTAMP()");
}
function q(string $sql, array $a = []): PDOStatement { $s = db()->prepare($sql); $s->execute($a); return $s; }
function row(string $sql, array $a = []): ?array { $r = q($sql, $a)->fetch(); return $r ?: null; }
function rows(string $sql, array $a = []): array { return q($sql, $a)->fetchAll(); }
function val(string $sql, array $a = []): mixed { $r = q($sql, $a)->fetch(PDO::FETCH_NUM); return $r ? $r[0] : null; }
function insert_id(): int { return (int)db()->lastInsertId(); }
function now(): string { return gmdate('Y-m-d H:i:s'); }
function add_days(string $utc, int $days): string {
    return (new DateTimeImmutable($utc, new DateTimeZone('UTC')))->modify(sprintf('%+d days', $days))->format('Y-m-d H:i:s');
}

/* ---------- رمزنگاری تنظیمات حساس ---------- */
function enc(string $s): string {
    $key = hash('sha256', (string)cfg('app_key'), true);
    $iv = random_bytes(12);
    $c = openssl_encrypt($s, 'aes-256-gcm', $key, OPENSSL_RAW_DATA, $iv, $tag);
    return 'enc:' . base64_encode($iv . $tag . $c);
}
function dec(string $s): string {
    if (!str_starts_with($s, 'enc:')) return $s;
    $raw = base64_decode(substr($s, 4), true);
    if ($raw === false || strlen($raw) < 29) return '';
    $key = hash('sha256', (string)cfg('app_key'), true);
    $p = openssl_decrypt(substr($raw, 28), 'aes-256-gcm', $key, OPENSSL_RAW_DATA, substr($raw, 0, 12), substr($raw, 12, 16));
    return $p === false ? '' : $p;
}

/* ---------- تنظیمات در دیتابیس ---------- */
const SECRET_SETTINGS = ['ippanel_api_key', 'zarinpal_merchant', 'zibal_merchant'];
const DEFAULT_SETTINGS = [
    'site_name' => 'نرم‌افزار حسابداری', 'support_text' => '', 'download_url' => '',
    'app_latest_version' => '1.0.0', 'app_min_version' => '1.0.0',
    'trial_enabled' => '1', 'trial_days' => '7',
    'ippanel_from_number' => '', 'ippanel_otp_pattern' => '', 'ippanel_otp_param' => 'code',
    'active_gateway' => 'zarinpal', 'gateway_zarinpal_enabled' => '0', 'gateway_zibal_enabled' => '0',
    'zarinpal_sandbox' => '0', 'zibal_test_mode' => '0',
    'club_sms_enabled' => '1', 'club_sms_daily_limit' => '300', 'club_sms_suffix' => '',
    'device_binds_30d' => '3', 'token_ttl_days' => '60',
];
function settings_all(bool $fresh = false): array {
    static $c = null;
    if ($c === null || $fresh) {
        $c = DEFAULT_SETTINGS;
        foreach (rows('SELECT k, v FROM settings') as $r) $c[$r['k']] = (string)$r['v'];
    }
    return $c;
}
function setting(string $k, string $d = ''): string {
    $v = settings_all()[$k] ?? $d;
    return in_array($k, SECRET_SETTINGS, true) ? dec($v) : $v;
}
function set_setting(string $k, string $v): void {
    if (in_array($k, SECRET_SETTINGS, true) && $v !== '') $v = enc($v);
    q('INSERT INTO settings(k, v, updated_at) VALUES(?,?,?) ON DUPLICATE KEY UPDATE v=VALUES(v), updated_at=VALUES(updated_at)', [$k, $v, now()]);
    settings_all(true);
}

/* ---------- ورودی و خروجی ---------- */
function e(mixed $s): string { return htmlspecialchars((string)$s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8'); }
function client_ip(): string {
    $h = cfg('ip_header');
    $ip = ($h && !empty($_SERVER[$h])) ? trim(explode(',', $_SERVER[$h])[0]) : ($_SERVER['REMOTE_ADDR'] ?? '0.0.0.0');
    return filter_var($ip, FILTER_VALIDATE_IP) ? $ip : '0.0.0.0';
}
function is_https(): bool {
    return (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') || (($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https');
}
function fa_to_en(string $s): string {
    return strtr($s, ['۰'=>'0','۱'=>'1','۲'=>'2','۳'=>'3','۴'=>'4','۵'=>'5','۶'=>'6','۷'=>'7','۸'=>'8','۹'=>'9',
                      '٠'=>'0','١'=>'1','٢'=>'2','٣'=>'3','٤'=>'4','٥'=>'5','٦'=>'6','٧'=>'7','٨'=>'8','٩'=>'9']);
}
function en_to_fa(string $s): string { return strtr($s, ['0'=>'۰','1'=>'۱','2'=>'۲','3'=>'۳','4'=>'۴','5'=>'۵','6'=>'۶','7'=>'۷','8'=>'۸','9'=>'۹']); }
function normalize_phone(string $p): ?string {
    $p = preg_replace('/[\s\-]/', '', fa_to_en(trim($p)));
    if (str_starts_with($p, '+98')) $p = '0' . substr($p, 3);
    elseif (str_starts_with($p, '0098')) $p = '0' . substr($p, 4);
    elseif (preg_match('/^9\d{9}$/', $p)) $p = '0' . $p;
    return preg_match('/^09\d{9}$/', $p) ? $p : null;
}
function money(int $n): string { return en_to_fa(number_format($n)) . ' تومان'; }

/* ---------- مسیر پایه (برای نصب در زیرپوشه، مثل localhost/sib/public) ---------- */
function base_path(): string {
    $d = str_replace('\\', '/', dirname($_SERVER['SCRIPT_NAME'] ?? ''));
    return ($d === '/' || $d === '.' || $d === '') ? '' : rtrim($d, '/');
}
function redir(string $to): never { header('Location: ' . base_path() . $to); exit; }
/** لینک‌ها و فرم‌های مطلق (href="/..") را نسبت به مسیر پایه بازنویسی می‌کند */
function rebase_output(): void {
    $b = base_path();
    if ($b === '') return;
    ob_start(fn(string $h) => preg_replace('#\b(href|action|src)="/(?!/)#', '$1="' . $b . '/', $h));
}

/* ---------- نشست و CSRF ---------- */
function start_session(string $name): void {
    if (session_status() === PHP_SESSION_ACTIVE) return;
    ini_set('session.use_strict_mode', '1');
    session_name($name);
    session_set_cookie_params(['lifetime' => 0, 'path' => '/', 'secure' => is_https(), 'httponly' => true, 'samesite' => 'Lax']);
    session_start();
}
function csrf_token(): string {
    if (empty($_SESSION['csrf'])) $_SESSION['csrf'] = bin2hex(random_bytes(24));
    return $_SESSION['csrf'];
}
function csrf_field(): string { return '<input type="hidden" name="_csrf" value="' . e(csrf_token()) . '">'; }
function csrf_check(): void {
    $t = $_POST['_csrf'] ?? '';
    if (!is_string($t) || !hash_equals($_SESSION['csrf'] ?? '', $t)) {
        http_response_code(419);
        exit('نشست منقضی شده است. صفحه را دوباره بارگذاری کنید.');
    }
}
function security_headers(): void {
    header('X-Frame-Options: DENY');
    header('X-Content-Type-Options: nosniff');
    header('Referrer-Policy: same-origin');
    header("Content-Security-Policy: default-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; frame-ancestors 'none'; form-action 'self' https:");
    if (is_https()) header('Strict-Transport-Security: max-age=31536000');
}

/* ---------- سهمیه و محدودسازی نرخ ---------- */
function quota_take(string $key, int $max, int $window, int $n = 1): bool {
    $pdo = db(); $t = time();
    $pdo->beginTransaction();
    try {
        $r = q('SELECT hits, window_start FROM rate_limits WHERE k=? FOR UPDATE', [$key])->fetch();
        if (!$r || $r['window_start'] + $window <= $t) { $hits = 0; $ws = $t; }
        else { $hits = (int)$r['hits']; $ws = (int)$r['window_start']; }
        if ($hits + $n > $max) { $pdo->commit(); return false; }
        q('INSERT INTO rate_limits(k,hits,window_start) VALUES(?,?,?) ON DUPLICATE KEY UPDATE hits=VALUES(hits), window_start=VALUES(window_start)', [$key, $hits + $n, $ws]);
        $pdo->commit();
        return true;
    } catch (Throwable $e) { if ($pdo->inTransaction()) $pdo->rollBack(); throw $e; }
}

/* ---------- درخواست HTTP خروجی ---------- */
function http_post_json(string $url, array $body, array $headers = [], int $timeout = 20): array {
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_POST => true, CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => $timeout, CURLOPT_CONNECTTIMEOUT => 8,
        CURLOPT_HTTPHEADER => array_merge(['Content-Type: application/json', 'Accept: application/json'], $headers),
        CURLOPT_POSTFIELDS => json_encode($body, JSON_UNESCAPED_UNICODE),
    ]);
    $resp = curl_exec($ch);
    $code = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $err = $resp === false ? curl_error($ch) : null;
    curl_close($ch);
    return [$code, $resp === false ? '' : (string)$resp, $err];
}

/* ---------- تقویم شمسی ---------- */
function g2j(int $gy, int $gm, int $gd): array {
    $gdm = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
    $gy2 = $gm > 2 ? $gy + 1 : $gy;
    $days = 355666 + 365 * $gy + intdiv($gy2 + 3, 4) - intdiv($gy2 + 99, 100) + intdiv($gy2 + 399, 400) + $gd + $gdm[$gm - 1];
    $jy = -1595 + 33 * intdiv($days, 12053); $days %= 12053;
    $jy += 4 * intdiv($days, 1461); $days %= 1461;
    if ($days > 365) { $jy += intdiv($days - 1, 365); $days = ($days - 1) % 365; }
    if ($days < 186) { $jm = 1 + intdiv($days, 31); $jd = 1 + $days % 31; }
    else { $jm = 7 + intdiv($days - 186, 30); $jd = 1 + ($days - 186) % 30; }
    return [$jy, $jm, $jd];
}
const J_MONTHS = ['', 'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور', 'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'];
function to_tehran(?string $utc): ?DateTimeImmutable {
    if (!$utc) return null;
    return (new DateTimeImmutable($utc, new DateTimeZone('UTC')))->setTimezone(new DateTimeZone(cfg('timezone', 'Asia/Tehran')));
}
function jdate(?string $utc, bool $time = true): string {
    $d = to_tehran($utc);
    if (!$d) return '—';
    [$y, $m, $dd] = g2j((int)$d->format('Y'), (int)$d->format('n'), (int)$d->format('j'));
    $s = sprintf('%04d/%02d/%02d', $y, $m, $dd) . ($time ? ' ' . $d->format('H:i') : '');
    return en_to_fa($s);
}
