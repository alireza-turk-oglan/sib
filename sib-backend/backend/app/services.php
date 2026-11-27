<?php
declare(strict_types=1);
require_once __DIR__ . '/core.php';

/* =====================  IPPanel (Edge API)  ===================== */
function e164(string $phone): string { return '+98' . substr($phone, 1); }

function sms_log(?int $uid, string $kind, int $count, bool $ok, ?string $err, ?string $resp): void {
    q('INSERT INTO sms_logs(user_id,kind,recipients_count,status,error,response,created_at) VALUES(?,?,?,?,?,?,?)',
      [$uid, $kind, $count, $ok ? 'sent' : 'failed', $err ? mb_substr($err, 0, 500) : null, $resp ? mb_substr($resp, 0, 1000) : null, now()]);
}

/** @return array{0:bool,1:?string} [موفق، پیام خطا] */
function ippanel_send(array $body): array {
    $key = setting('ippanel_api_key');
    $from = setting('ippanel_from_number');
    if ($key === '' || $from === '') return [false, 'تنظیمات IPPanel کامل نیست.'];
    $body['from_number'] = $from;
    [$code, $resp, $err] = http_post_json(rtrim((string)cfg('ippanel_base', 'https://edge.ippanel.com/v1'), '/') . '/api/send', $body, ['Authorization: ' . $key]);
    if ($err) return [false, "خطای اتصال: $err"];
    $j = json_decode($resp, true);
    if ($code >= 200 && $code < 300 && is_array($j) && ($j['meta']['status'] ?? false) === true) return [true, null];
    $msg = is_array($j) ? ($j['meta']['message'] ?? 'خطای نامشخص') : 'پاسخ نامعتبر';
    return [false, "HTTP $code: $msg"];
}

function sms_send_otp(string $phone, string $code): array {
    $pattern = setting('ippanel_otp_pattern');
    if ($pattern === '') { sms_log(null, 'otp', 1, false, 'پترن OTP تنظیم نشده', null); return [false, 'تنظیمات پیامک کامل نیست.']; }
    [$ok, $err] = ippanel_send([
        'sending_type' => 'pattern', 'code' => $pattern, 'recipients' => [e164($phone)],
        'params' => [setting('ippanel_otp_param', 'code') => $code],
    ]);
    sms_log(null, 'otp', 1, $ok, $err, null);
    if (!$ok) app_log('error', 'OTP SMS failed', ['err' => $err]);
    return [$ok, $ok ? null : 'ارسال پیامک ناموفق بود. چند دقیقه بعد دوباره تلاش کنید.'];
}

/** ارسال پیام به چند شماره (باشگاه مشتریان). خروجی: [شماره => null|خطا] */
function sms_send_bulk(int $uid, array $phones, string $message): array {
    $result = [];
    foreach (array_chunk($phones, 100) as $chunk) {
        [$ok, $err] = ippanel_send([
            'sending_type' => 'webservice', 'message' => $message,
            'params' => ['recipients' => array_map('e164', $chunk)],
        ]);
        sms_log($uid, 'club', count($chunk), $ok, $err, null);
        foreach ($chunk as $p) $result[$p] = $ok ? null : ($err ?? 'خطا');
    }
    return $result;
}

/* =====================  OTP  ===================== */
const OTP_TTL = 120;
const OTP_RESEND = 60;

function otp_hash(string $phone, string $code): string { return hash_hmac('sha256', $code, (string)cfg('app_key') . $phone); }

/** @return array{ok:bool,error?:string,wait?:int} */
function otp_issue(string $phone, string $purpose): array {
    $ip = client_ip();
    $last = val('SELECT created_at FROM otp_codes WHERE phone=? ORDER BY id DESC LIMIT 1', [$phone]);
    if ($last) {
        $wait = OTP_RESEND - (time() - strtotime($last . ' UTC'));
        if ($wait > 0) return ['ok' => false, 'error' => "لطفاً $wait ثانیه دیگر دوباره تلاش کنید.", 'wait' => $wait];
    }
    if (!quota_take("otp:phone:$phone", 5, 3600) || !quota_take("otp:ip:$ip", 30, 3600)) {
        return ['ok' => false, 'error' => 'تعداد درخواست‌ها بیش از حد مجاز است. بعداً تلاش کنید.', 'wait' => 600];
    }
    $code = sprintf('%06d', random_int(0, 999999));
    q('INSERT INTO otp_codes(phone,code_hash,purpose,expires_at,ip,created_at) VALUES(?,?,?,?,?,?)',
      [$phone, otp_hash($phone, $code), $purpose, gmdate('Y-m-d H:i:s', time() + OTP_TTL), $ip, now()]);
    $id = insert_id();
    [$ok, $err] = sms_send_otp($phone, $code);
    if (!$ok) { q('UPDATE otp_codes SET used_at=? WHERE id=?', [now(), $id]); return ['ok' => false, 'error' => $err]; }
    return ['ok' => true];
}

function otp_verify(string $phone, string $purpose, string $code): bool {
    $code = fa_to_en(trim($code));
    if (!preg_match('/^\d{6}$/', $code)) return false;
    $r = row('SELECT * FROM otp_codes WHERE phone=? AND purpose=? AND used_at IS NULL AND expires_at>? ORDER BY id DESC LIMIT 1', [$phone, $purpose, now()]);
    if (!$r) return false;
    if ($r['attempts'] >= 5) return false;
    q('UPDATE otp_codes SET attempts=attempts+1 WHERE id=?', [$r['id']]);
    if (!hash_equals($r['code_hash'], otp_hash($phone, $code))) return false;
    // مصرف اتمیک: فقط یک درخواست می‌تواند کد را مصرف کند
    return q('UPDATE otp_codes SET used_at=? WHERE id=? AND used_at IS NULL', [now(), $r['id']])->rowCount() === 1;
}

/* =====================  کاربران و اشتراک  ===================== */
function user_by_phone(string $phone): ?array { return row('SELECT * FROM users WHERE phone=?', [$phone]); }

/** نام و نام خانوادگی: فقط حروف/فاصله، ۳ تا ۱۰۰ کاراکتر. null = نامعتبر */
function clean_full_name(string $s): ?string {
    $s = trim((string)preg_replace('/\s+/u', ' ', strip_tags($s)));
    $s = str_replace(['ي', 'ك', 'ى'], ['ی', 'ک', 'ی'], $s);
    $len = mb_strlen($s);
    if ($len < 3 || $len > 100) return null;
    if (!preg_match('/^[\p{L}\p{M}\x{200C} .\'\-]+$/u', $s)) return null;
    if (preg_match_all('/\p{L}/u', $s) < 2) return null;
    return $s;
}

/** نام نمایشی کاربر: نام و نام خانوادگی؛ اگر ثبت نشده باشد شماره موبایل */
function user_display_name(array $u): string {
    $n = trim((string)($u['full_name'] ?? ''));
    return $n !== '' ? $n : (string)$u['phone'];
}

function user_create(string $phone, ?string $name = null): int {
    q('INSERT INTO users(phone,full_name,created_at) VALUES(?,?,?)', [$phone, $name, now()]);
    $uid = insert_id();
    if (setting('trial_enabled') === '1' && (int)setting('trial_days') > 0) {
        sub_grant($uid, 'trial', 'auto', (int)setting('trial_days'), note: 'اشتراک آزمایشی خودکار');
    }
    return $uid;
}

/** افزودن مدت به انتهای اشتراک فعلی (یا از همین لحظه اگر اشتراکی فعال نیست) */
function sub_grant(int $uid, string $type, string $source, int $days, ?int $planId = null, ?int $paymentId = null, ?int $adminId = null, ?string $note = null): int {
    $end = val("SELECT MAX(ends_at) FROM subscriptions WHERE user_id=? AND status='active'", [$uid]);
    $start = ($end && $end > now()) ? $end : now();
    q('INSERT INTO subscriptions(user_id,plan_id,payment_id,type,source,starts_at,ends_at,created_at,created_by_admin,note) VALUES(?,?,?,?,?,?,?,?,?,?)',
      [$uid, $planId, $paymentId, $type, $source, $start, add_days($start, $days), now(), $adminId, $note]);
    return insert_id();
}

/** وضعیت اشتراک: active | suspended | expired | none | blocked */
function sub_status(int $uid): array {
    $u = row('SELECT status FROM users WHERE id=?', [$uid]);
    $n = now();
    $cur = row("SELECT type, ends_at FROM subscriptions WHERE user_id=? AND status='active' AND starts_at<=? AND ends_at>? ORDER BY ends_at DESC LIMIT 1", [$uid, $n, $n]);
    $out = ['status' => 'none', 'type' => null, 'ends_at' => null, 'days_left' => 0];
    if ($cur) {
        $end = (string)val("SELECT MAX(ends_at) FROM subscriptions WHERE user_id=? AND status='active'", [$uid]);
        $out = ['status' => 'active', 'type' => $cur['type'], 'ends_at' => $end,
                'days_left' => (int)ceil((strtotime($end . ' UTC') - time()) / 86400)];
    } elseif (val("SELECT COUNT(*) FROM subscriptions WHERE user_id=? AND status='suspended' AND ends_at>?", [$uid, $n])) {
        $out['status'] = 'suspended';
    } else {
        $last = val("SELECT MAX(ends_at) FROM subscriptions WHERE user_id=? AND status<>'cancelled'", [$uid]);
        if ($last) { $out['status'] = 'expired'; $out['ends_at'] = $last; }
    }
    if (!$u || $u['status'] === 'blocked') $out['status'] = 'blocked';
    return $out;
}

function sub_public(array $s): array {
    return ['status' => $s['status'], 'type' => $s['type'],
            'ends_at' => $s['ends_at'] ? gmdate('c', strtotime($s['ends_at'] . ' UTC')) : null, 'days_left' => $s['days_left']];
}

/* =====================  توکن و دستگاه  ===================== */
function token_issue(int $uid, string $deviceId): array {
    $t = bin2hex(random_bytes(32));
    $exp = add_days(now(), max(1, (int)setting('token_ttl_days', '60')));
    q('INSERT INTO api_tokens(user_id,token_hash,device_id,created_at,last_used_at,expires_at) VALUES(?,?,?,?,?,?)',
      [$uid, hash('sha256', $t), $deviceId, now(), now(), $exp]);
    return [$t, $exp];
}

/** @return array{0:bool,1:?string} [موفق، کد خطا] */
function device_bind(int $uid, string $deviceId, string $name): array {
    $cur = row('SELECT * FROM user_devices WHERE user_id=? AND unbound_at IS NULL ORDER BY id DESC LIMIT 1', [$uid]);
    if ($cur && $cur['device_id'] === $deviceId) return [true, null];
    if ($cur) {
        $limit = max(1, (int)setting('device_binds_30d', '3'));
        $recent = (int)val('SELECT COUNT(*) FROM user_devices WHERE user_id=? AND bound_at>?', [$uid, add_days(now(), -30)]);
        if ($recent >= $limit) return [false, 'device_limit'];
        q('UPDATE user_devices SET unbound_at=? WHERE user_id=? AND unbound_at IS NULL', [now(), $uid]);
    }
    q('INSERT INTO user_devices(user_id,device_id,device_name,bound_at) VALUES(?,?,?,?)', [$uid, $deviceId, mb_substr($name, 0, 64), now()]);
    q('UPDATE api_tokens SET revoked_at=? WHERE user_id=? AND device_id<>? AND revoked_at IS NULL', [now(), $uid, $deviceId]);
    return [true, null];
}

/** احراز هویت توکن Bearer + شناسه دستگاه. @return array{user:array,token:array}|string کد خطا */
function token_auth(string $deviceId): array|string {
    $h = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    if (!preg_match('/^Bearer\s+([a-f0-9]{64})$/i', $h, $m)) return 'token_invalid';
    $t = row('SELECT * FROM api_tokens WHERE token_hash=?', [hash('sha256', strtolower($m[1]))]);
    if (!$t || $t['revoked_at'] || $t['expires_at'] <= now()) return 'token_invalid';
    if (!hash_equals($t['device_id'], $deviceId)) return 'device_mismatch';
    $u = row('SELECT * FROM users WHERE id=?', [$t['user_id']]);
    if (!$u || $u['status'] !== 'active') return 'blocked';
    q('UPDATE api_tokens SET last_used_at=?, expires_at=? WHERE id=?', [now(), add_days(now(), max(1, (int)setting('token_ttl_days', '60'))), $t['id']]);
    return ['user' => $u, 'token' => $t];
}

/* =====================  درگاه‌های پرداخت  ===================== */
function zp_api(): string { return rtrim((string)cfg('zarinpal_api', setting('zarinpal_sandbox') === '1' ? 'https://sandbox.zarinpal.com' : 'https://payment.zarinpal.com'), '/'); }
function zp_pay(): string { return rtrim((string)cfg('zarinpal_pay', setting('zarinpal_sandbox') === '1' ? 'https://sandbox.zarinpal.com' : 'https://www.zarinpal.com'), '/'); }
function zb_base(): string { return rtrim((string)cfg('zibal_base', 'https://gateway.zibal.ir'), '/'); }

function gateways_enabled(): array {
    $o = [];
    if (setting('gateway_zarinpal_enabled') === '1' && setting('zarinpal_merchant') !== '') $o['zarinpal'] = 'زرین‌پال';
    if (setting('gateway_zibal_enabled') === '1' && (setting('zibal_merchant') !== '' || setting('zibal_test_mode') === '1')) $o['zibal'] = 'زیبال';
    return $o;
}
function gateway_active(): ?string {
    $en = gateways_enabled();
    if (!$en) return null;
    $a = setting('active_gateway');
    return isset($en[$a]) ? $a : array_key_first($en);
}

/** ایجاد درخواست پرداخت. @return array{ok:bool,url?:string,error?:string} */
function pay_start(int $uid, array $plan): array {
    $gw = gateway_active();
    if (!$gw) return ['ok' => false, 'error' => 'درگاه پرداخت فعال نیست. با پشتیبانی تماس بگیرید.'];
    $user = row('SELECT phone FROM users WHERE id=?', [$uid]);
    $track = strtoupper(bin2hex(random_bytes(8)));
    q('INSERT INTO payments(user_id,plan_id,amount,gateway,tracking_code,ip,created_at) VALUES(?,?,?,?,?,?,?)',
      [$uid, $plan['id'], $plan['price'], $gw, $track, client_ip(), now()]);
    $pid = insert_id();
    $cb = rtrim((string)cfg('site_url'), '/') . '/pay/callback?gw=' . $gw;
    $desc = 'خرید اشتراک ' . $plan['title'];
    try {
        if ($gw === 'zarinpal') {
            [$code, $resp, $err] = http_post_json(zp_api() . '/pg/v4/payment/request.json', [
                'merchant_id' => setting('zarinpal_merchant'), 'currency' => 'IRT', 'amount' => (int)$plan['price'],
                'callback_url' => $cb, 'description' => $desc, 'metadata' => ['mobile' => $user['phone']],
            ]);
            $j = json_decode($resp, true);
            $auth = is_array($j) ? ($j['data']['authority'] ?? null) : null;
            if ($err || ($j['data']['code'] ?? 0) !== 100 || !$auth) throw new RuntimeException($err ?: ('zarinpal request: ' . substr($resp, 0, 300)));
            $payUrl = zp_pay() . '/pg/StartPay/' . $auth;
        } else {
            // زیبال مبلغ را به ریال می‌گیرد
            [$code, $resp, $err] = http_post_json(zb_base() . '/v1/request', [
                'merchant' => setting('zibal_test_mode') === '1' ? 'zibal' : setting('zibal_merchant'),
                'amount' => (int)$plan['price'] * 10, 'callbackUrl' => $cb, 'description' => $desc,
                'orderId' => $track, 'mobile' => $user['phone'],
            ]);
            $j = json_decode($resp, true);
            $auth = is_array($j) && isset($j['trackId']) ? (string)$j['trackId'] : null;
            if ($err || ($j['result'] ?? 0) !== 100 || !$auth) throw new RuntimeException($err ?: ('zibal request: ' . substr($resp, 0, 300)));
            $payUrl = zb_base() . '/start/' . $auth;
        }
    } catch (Throwable $e) {
        q("UPDATE payments SET status='failed', error=? WHERE id=?", [mb_substr($e->getMessage(), 0, 255), $pid]);
        app_log('error', 'pay_start failed', ['gw' => $gw, 'err' => $e->getMessage()]);
        return ['ok' => false, 'error' => 'اتصال به درگاه پرداخت برقرار نشد. دوباره تلاش کنید.'];
    }
    q('UPDATE payments SET authority=? WHERE id=?', [$auth, $pid]);
    return ['ok' => true, 'url' => $payUrl];
}

/**
 * بازگشت از درگاه + تأیید سمت سرور. اشتراک فقط پس از Verify موفق فعال می‌شود
 * و فقط یک بار (قفل ردیف پرداخت + شرط وضعیت pending).
 * @return array{ok:bool,message:string,payment?:array}
 */
function pay_callback(string $gw, array $q): array {
    if (!in_array($gw, ['zarinpal', 'zibal'], true)) return ['ok' => false, 'message' => 'درگاه نامعتبر است.'];
    $authority = $gw === 'zarinpal' ? (string)($q['Authority'] ?? '') : (string)($q['trackId'] ?? '');
    if (!preg_match('/^[A-Za-z0-9]{1,64}$/', $authority)) return ['ok' => false, 'message' => 'اطلاعات بازگشتی نامعتبر است.'];
    $pdo = db();
    $pdo->beginTransaction();
    try {
        $p = q('SELECT * FROM payments WHERE gateway=? AND authority=? FOR UPDATE', [$gw, $authority])->fetch();
        if (!$p) { $pdo->commit(); return ['ok' => false, 'message' => 'تراکنش یافت نشد.']; }
        if ($p['status'] === 'paid') { $pdo->commit(); return ['ok' => true, 'message' => 'این پرداخت قبلاً تأیید شده است.', 'payment' => $p]; }
        if ($p['status'] !== 'pending') { $pdo->commit(); return ['ok' => false, 'message' => 'این تراکنش ناموفق ثبت شده است.', 'payment' => $p]; }

        $cancelled = $gw === 'zarinpal' ? (($q['Status'] ?? '') !== 'OK') : ((string)($q['success'] ?? '') !== '1');
        if ($cancelled) {
            q("UPDATE payments SET status='failed', error=? WHERE id=?", ['انصراف یا ناموفق در درگاه', $p['id']]);
            $pdo->commit();
            return ['ok' => false, 'message' => 'پرداخت انجام نشد یا لغو شد.', 'payment' => $p];
        }

        $ref = null; $verified = false; $err = null;
        if ($gw === 'zarinpal') {
            [$code, $resp, $e1] = http_post_json(zp_api() . '/pg/v4/payment/verify.json',
                ['merchant_id' => setting('zarinpal_merchant'), 'amount' => (int)$p['amount'], 'authority' => $authority]);
            $j = json_decode($resp, true);
            $c = is_array($j) ? ($j['data']['code'] ?? null) : null;
            if ($e1) $err = $e1;
            elseif (in_array($c, [100, 101], true)) { $verified = true; $ref = (string)($j['data']['ref_id'] ?? ''); }
            else $err = 'verify code ' . json_encode($c) . ' ' . json_encode($j['errors'] ?? null);
        } else {
            [$code, $resp, $e1] = http_post_json(zb_base() . '/v1/verify',
                ['merchant' => setting('zibal_test_mode') === '1' ? 'zibal' : setting('zibal_merchant'), 'trackId' => (int)$authority]);
            $j = json_decode($resp, true);
            $c = is_array($j) ? ($j['result'] ?? null) : null;
            if ($e1) $err = $e1;
            elseif (in_array($c, [100, 201], true)) {
                if ((int)($j['amount'] ?? 0) !== (int)$p['amount'] * 10) $err = 'مبلغ تأییدشده با مبلغ سفارش یکسان نیست';
                else { $verified = true; $ref = (string)($j['refNumber'] ?? ''); }
            } else $err = 'verify result ' . json_encode($c);
        }

        if (!$verified) {
            // خطای شبکه موقتی نباید پرداخت را قطعی «ناموفق» کند؛ در حالت pending باقی می‌ماند تا دوباره بررسی شود
            $final = $e1 ? 'pending' : 'failed';
            q('UPDATE payments SET status=?, error=? WHERE id=?', [$final, mb_substr((string)$err, 0, 255), $p['id']]);
            $pdo->commit();
            app_log('error', 'pay verify failed', ['gw' => $gw, 'id' => $p['id'], 'err' => $err]);
            return ['ok' => false, 'message' => $e1 ? 'تأیید پرداخت با خطای ارتباطی روبه‌رو شد. چند دقیقه بعد صفحه را دوباره باز کنید.' : 'تأیید پرداخت ناموفق بود.', 'payment' => $p];
        }

        $plan = row('SELECT * FROM plans WHERE id=?', [$p['plan_id']]);
        q("UPDATE payments SET status='paid', ref_id=?, paid_at=?, error=NULL WHERE id=?", [$ref, now(), $p['id']]);
        sub_grant((int)$p['user_id'], 'paid', 'payment', (int)$plan['duration_days'], (int)$plan['id'], (int)$p['id']);
        $pdo->commit();
        $p['status'] = 'paid'; $p['ref_id'] = $ref;
        return ['ok' => true, 'message' => 'پرداخت با موفقیت انجام شد و اشتراک شما فعال شد.', 'payment' => $p];
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        app_log('error', 'pay_callback exception', ['err' => $e->getMessage()]);
        return ['ok' => false, 'message' => 'خطای داخلی. لطفاً با پشتیبانی تماس بگیرید.'];
    }
}
