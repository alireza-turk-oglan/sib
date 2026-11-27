<?php
declare(strict_types=1);
require __DIR__ . '/../app/services.php';

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');

function reply(int $status, array $data): never {
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}
function fail(int $status, string $code, string $msg, array $extra = []): never {
    reply($status, ['ok' => false, 'code' => $code, 'message' => $msg] + $extra);
}

set_exception_handler(function (Throwable $e) {
    app_log('error', 'api exception: ' . $e->getMessage(), ['file' => $e->getFile(), 'line' => $e->getLine()]);
    fail(500, 'server_error', cfg('debug') ? $e->getMessage() : 'خطای داخلی سرور.');
});

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') fail(405, 'method_not_allowed', 'فقط POST مجاز است.');
$raw = file_get_contents('php://input', false, null, 0, 65537);
if (strlen((string)$raw) > 65536) fail(413, 'too_large', 'حجم درخواست زیاد است.');
$in = json_decode((string)$raw, true);
if (!is_array($in)) fail(400, 'bad_json', 'بدنه درخواست باید JSON معتبر باشد.');

$route = trim((string)($_GET['r'] ?? ''), '/');
$ip = client_ip();
if (!quota_take("api:ip:$ip", 300, 60)) fail(429, 'rate_limited', 'تعداد درخواست‌ها زیاد است.');

function in_str(array $in, string $k, int $max = 200): string {
    $v = $in[$k] ?? '';
    return is_string($v) ? mb_substr(trim($v), 0, $max) : '';
}
function device_id_of(array $in): string {
    $d = in_str($in, 'device_id', 64);
    if (!preg_match('/^[A-Za-z0-9_\-]{16,64}$/', $d)) fail(422, 'bad_device', 'شناسه دستگاه نامعتبر است.');
    return $d;
}
function app_info(): array {
    return ['latest_version' => setting('app_latest_version'), 'min_version' => setting('app_min_version'), 'download_url' => setting('download_url')];
}
function inactive_error(array $sub): never {
    $msgs = ['expired' => 'اشتراک شما منقضی شده است.', 'none' => 'اشتراک فعالی برای شما ثبت نشده است.',
             'suspended' => 'اشتراک شما موقتاً متوقف شده است.', 'blocked' => 'حساب کاربری شما مسدود است.'];
    fail(402, $sub['status'] === 'blocked' ? 'blocked' : 'subscription_inactive', $msgs[$sub['status']] ?? 'اشتراک فعال نیست.',
         ['subscription' => sub_public($sub), 'app' => app_info()]);
}
function auth_or_fail(array $in): array {
    $dev = device_id_of($in);
    $a = token_auth($dev);
    if (is_string($a)) {
        $m = ['token_invalid' => 'نشست شما معتبر نیست. دوباره وارد شوید.', 'device_mismatch' => 'این حساب روی دستگاه دیگری فعال شده است.', 'blocked' => 'حساب کاربری شما مسدود است.'];
        fail($a === 'blocked' ? 403 : 401, $a, $m[$a]);
    }
    return $a;
}

switch ($route) {
    case 'auth/otp/request': {
        $phone = normalize_phone(in_str($in, 'phone', 20));
        if (!$phone) fail(422, 'bad_phone', 'شماره موبایل نامعتبر است. فرمت صحیح: 09xxxxxxxxx');
        $u = user_by_phone($phone);
        if (!$u) fail(404, 'not_registered', 'این شماره هنوز در سایت ثبت‌نام نکرده است. ابتدا در وب‌سایت ثبت‌نام کنید.');
        if ($u['status'] === 'blocked') fail(403, 'blocked', 'حساب کاربری شما مسدود است.');
        $r = otp_issue($phone, 'app');
        if (!$r['ok']) fail(429, 'otp_failed', $r['error'] ?? 'خطا', ['wait' => $r['wait'] ?? 0]);
        reply(200, ['ok' => true, 'ttl' => OTP_TTL, 'resend_after' => OTP_RESEND]);
    }

    case 'auth/otp/verify': {
        $phone = normalize_phone(in_str($in, 'phone', 20));
        $dev = device_id_of($in);
        if (!$phone) fail(422, 'bad_phone', 'شماره موبایل نامعتبر است.');
        if (!quota_take("otpv:$ip:$phone", 10, 900)) fail(429, 'rate_limited', 'تلاش‌های ناموفق زیاد بود. چند دقیقه بعد دوباره امتحان کنید.');
        if (!otp_verify($phone, 'app', in_str($in, 'code', 12))) fail(401, 'bad_code', 'کد تأیید اشتباه یا منقضی شده است.');
        $u = user_by_phone($phone);
        if (!$u) fail(404, 'not_registered', 'کاربر یافت نشد.');
        $sub = sub_status((int)$u['id']);
        if ($sub['status'] !== 'active') inactive_error($sub);
        [$ok, $why] = device_bind((int)$u['id'], $dev, in_str($in, 'device_name', 64));
        if (!$ok) fail(409, 'device_limit', 'تعداد دفعات تغییر دستگاه در ۳۰ روز گذشته به حد مجاز رسیده است. با پشتیبانی تماس بگیرید.');
        [$token, $exp] = token_issue((int)$u['id'], $dev);
        q('UPDATE users SET last_login_at=? WHERE id=?', [now(), $u['id']]);
        reply(200, ['ok' => true, 'token' => $token, 'expires_at' => gmdate('c', strtotime($exp . ' UTC')),
                    'user' => ['phone' => $u['phone'], 'name' => $u['full_name']], 'subscription' => sub_public($sub), 'app' => app_info(), 'server_time' => gmdate('c')]);
    }

    case 'auth/check': {
        $a = auth_or_fail($in);
        if (!quota_take('chk:' . $a['token']['id'], 60, 60)) fail(429, 'rate_limited', 'تعداد درخواست‌ها زیاد است.');
        $sub = sub_status((int)$a['user']['id']);
        if ($sub['status'] !== 'active') inactive_error($sub);
        reply(200, ['ok' => true, 'user' => ['phone' => $a['user']['phone'], 'name' => $a['user']['full_name']], 'subscription' => sub_public($sub), 'app' => app_info(), 'server_time' => gmdate('c')]);
    }

    case 'auth/logout': {
        $a = auth_or_fail($in);
        q('UPDATE api_tokens SET revoked_at=? WHERE id=?', [now(), $a['token']['id']]);
        reply(200, ['ok' => true]);
    }

    case 'sms/send': {
        $a = auth_or_fail($in);
        $uid = (int)$a['user']['id'];
        $sub = sub_status($uid);
        if ($sub['status'] !== 'active') inactive_error($sub);
        if (setting('club_sms_enabled') !== '1') fail(403, 'sms_disabled', 'ارسال پیامک در حال حاضر غیرفعال است.');
        $msg = in_str($in, 'message', 600);
        if (mb_strlen($msg) < 2) fail(422, 'bad_message', 'متن پیامک خالی است.');
        $suffix = setting('club_sms_suffix');
        if ($suffix !== '') $msg .= "\n" . $suffix;
        $list = [];
        foreach ((is_array($in['recipients'] ?? null) ? $in['recipients'] : []) as $r) {
            $n = is_string($r) ? normalize_phone($r) : null;
            if ($n) $list[$n] = true;
        }
        $list = array_keys($list);
        if (!$list) fail(422, 'no_recipients', 'گیرنده معتبری انتخاب نشده است.');
        if (count($list) > 500) fail(422, 'too_many', 'در هر درخواست حداکثر ۵۰۰ گیرنده مجاز است.');
        $limit = max(1, (int)setting('club_sms_daily_limit', '300'));
        if (!quota_take("club:$uid", $limit, 86400, count($list))) fail(429, 'daily_limit', "سقف ارسال روزانه ($limit پیامک) پر شده است.");
        $res = sms_send_bulk($uid, $list, $msg);
        $out = []; $sent = 0;
        foreach ($res as $p => $err) { $out[] = ['phone' => $p, 'status' => $err === null ? 'sent' : 'failed', 'error' => $err]; if ($err === null) $sent++; }
        reply(200, ['ok' => true, 'sent' => $sent, 'failed' => count($list) - $sent, 'results' => $out]);
    }

    default:
        fail(404, 'not_found', 'مسیر یافت نشد.');
}
