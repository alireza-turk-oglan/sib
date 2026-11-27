<?php

declare(strict_types=1);
require __DIR__ . '/../app/services.php';

security_headers();
header('Content-Type: text/html; charset=utf-8');
header('Cache-Control: no-store');
header('X-Robots-Tag: noindex, nofollow');
set_exception_handler(function (Throwable $e) {
    app_log('error', 'admin exception: ' . $e->getMessage(), ['file' => $e->getFile(), 'line' => $e->getLine()]);
    http_response_code(500);
    echo cfg('debug') ? '<pre>' . e((string)$e) . '</pre>' : 'خطای داخلی سرور.';
    exit;
});
start_session('acc_adm');
rebase_output();

$path = '/' . trim((string)parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH), '/');
$base = rtrim(dirname($_SERVER['SCRIPT_NAME'] ?? ''), '/');
if ($base !== '' && str_starts_with($path, $base)) $path = '/' . trim(substr($path, strlen($base)), '/');
$path = preg_replace('#^/admin(\.php)?#', '', $path) ?: '/';
$isPost = ($_SERVER['REQUEST_METHOD'] ?? '') === 'POST';
if ($isPost) csrf_check();

/* ---------- ابزارها ---------- */
function alog(string $action, string $target = '', string $details = ''): void
{
    q(
        'INSERT INTO admin_logs(admin_id,action,target,details,ip,created_at) VALUES(?,?,?,?,?,?)',
        [$_SESSION['aid'] ?? null, $action, mb_substr($target, 0, 64), mb_substr($details, 0, 500), client_ip(), now()]
    );
}
function ok(string $m): string
{
    return '<div class="alert ok">' . e($m) . '</div>';
}
function bad(string $m): string
{
    return '<div class="alert err">' . e($m) . '</div>';
}
function go(string $to): never
{
    redir('/admin' . $to);
}
function flash_set(string $html): void
{
    $_SESSION['aflash'] = $html;
}
function flash_get(): string
{
    $f = $_SESSION['aflash'] ?? '';
    unset($_SESSION['aflash']);
    return $f;
}

function layout(string $title, string $body, string $active = ''): never
{
    global $A;
    $menu = ['/' => 'داشبورد', '/users' => 'کاربران', '/subscriptions' => 'اشتراک‌ها', '/plans' => 'پلن‌ها', '/payments' => 'پرداخت‌ها', '/sms-logs' => 'گزارش پیامک', '/logs' => 'فعالیت‌ها'];
    if ($A['role'] === 'super') {
        $menu['/settings'] = 'تنظیمات';
        $menu['/admins'] = 'مدیران';
    }
    echo '<!doctype html><html lang="fa" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex">'
        . '<title>' . e($title) . ' | پنل مدیریت</title><link rel="stylesheet" href="/assets/style.css"></head><body>'
        . '<header class="top"><div class="wrap"><span class="brand">پنل مدیریت</span><nav><span class="muted">' . e($A['username']) . '</span>'
        . '<form method="post" action="/admin/logout" class="inline">' . csrf_field() . '<button class="link">خروج</button></form></nav></div></header>'
        . '<main class="wrap"><div class="adm"><aside class="side">';
    foreach ($menu as $k => $v) echo '<a href="/admin' . ($k === '/' ? '' : $k) . '" class="' . ($active === $k ? 'on' : '') . '">' . $v . '</a>';
    echo '</aside><section>' . flash_get() . '<h1>' . e($title) . '</h1>' . $body . '</section></div></main></body></html>';
    exit;
}
function pager(int $total, int $per, int $page, string $qs): string
{
    $pages = (int)max(1, ceil($total / $per));
    if ($pages <= 1) return '';
    $o = '<div class="pager">';
    for ($i = max(1, $page - 3); $i <= min($pages, $page + 3); $i++) $o .= '<a class="btn small' . ($i === $page ? '' : ' ghost') . '" href="?' . e($qs) . 'page=' . $i . '">' . en_to_fa((string)$i) . '</a>';
    return $o . '</div>';
}
function badge(string $s): string
{
    $m = [
        'active' => ['فعال', 'ok'],
        'blocked' => ['مسدود', 'err'],
        'expired' => ['منقضی', 'err'],
        'none' => ['بدون اشتراک', ''],
        'suspended' => ['متوقف', 'warn'],
        'paid' => ['موفق', 'ok'],
        'pending' => ['در انتظار', 'warn'],
        'failed' => ['ناموفق', 'err'],
        'cancelled' => ['لغو', 'err'],
        'sent' => ['ارسال شد', 'ok']
    ];
    [$t, $c] = $m[$s] ?? [$s, ''];
    return '<span class="badge ' . $c . '">' . $t . '</span>';
}
$TYPE = ['trial' => 'آزمایشی', 'free' => 'رایگان', 'paid' => 'خریداری‌شده'];
$GW = ['zarinpal' => 'زرین‌پال', 'zibal' => 'زیبال'];

/* ---------- ورود مدیر ---------- */
if ($path === '/login') {
    $msg = '';
    if ($isPost) {
        $ip = client_ip();
        $uname = mb_substr(trim((string)($_POST['username'] ?? '')), 0, 40);
        $a = row('SELECT * FROM admins WHERE username=?', [$uname]);
        if (!quota_take("adm:login:$ip", 10, 900)) $msg = bad('تلاش‌های ناموفق زیاد بود. ۱۵ دقیقه بعد دوباره امتحان کنید.');
        elseif ($a && $a['locked_until'] && $a['locked_until'] > now()) $msg = bad('حساب موقتاً قفل شده است. بعداً تلاش کنید.');
        else {
            $good = password_verify((string)($_POST['password'] ?? ''), $a['password_hash'] ?? '$2y$10$abcdefghijklmnopqrstuuWzQmV8r2K3nQ6x1Yq0e1m5k9p8d7s2e');
            if ($a && $a['status'] === 'active' && $good) {
                session_regenerate_id(true);
                $_SESSION['aid'] = (int)$a['id'];
                $_SESSION['alast'] = time();
                q('UPDATE admins SET failed_attempts=0, locked_until=NULL, last_login_at=? WHERE id=?', [now(), $a['id']]);
                alog('login');
                go('');
            }
            if ($a) {
                $f = (int)$a['failed_attempts'] + 1;
                q('UPDATE admins SET failed_attempts=?, locked_until=? WHERE id=?', [$f >= 5 ? 0 : $f, $f >= 5 ? add_minutes(15) : null, $a['id']]);
            }
            $msg = bad('نام کاربری یا رمز عبور اشتباه است.');
        }
    }
    echo '<!doctype html><html lang="fa" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex"><title>ورود مدیر</title><link rel="stylesheet" href="/assets/style.css"></head><body><main class="wrap">'
        . '<div class="card narrow"><h1>ورود مدیر</h1>' . $msg . '<form method="post">' . csrf_field()
        . '<label>نام کاربری</label><input name="username" dir="ltr" required autofocus><label>رمز عبور</label><input type="password" name="password" dir="ltr" required>'
        . '<button class="btn">ورود</button></form></div></main></body></html>';
    exit;
}
function add_minutes(int $m): string
{
    return gmdate('Y-m-d H:i:s', time() + $m * 60);
}

/* ---------- احراز هویت ---------- */
$A = !empty($_SESSION['aid']) ? row("SELECT * FROM admins WHERE id=? AND status='active'", [$_SESSION['aid']]) : null;
if ($A && time() - (int)($_SESSION['alast'] ?? 0) > 7200) $A = null;   // انقضای نشست پس از ۲ ساعت عدم فعالیت
if (!$A) {
    session_destroy();
    go('/login');
}
$_SESSION['alast'] = time();
function need_super(): void
{
    global $A;
    if ($A['role'] !== 'super') {
        http_response_code(403);
        exit('دسترسی غیرمجاز.');
    }
}

if ($path === '/logout') {
    if ($isPost) {
        alog('logout');
        session_destroy();
    }
    go('/login');
}

/* ---------- صفحات ---------- */
if ($path === '/') {
    $n = now();
    $cover = "status='active' AND starts_at<=? AND ends_at>?";
    $cnt = fn(string $type = '') => (int)val("SELECT COUNT(DISTINCT user_id) FROM subscriptions WHERE $cover" . ($type ? " AND type='$type'" : ''), [$n, $n]);
    $expired = (int)val("SELECT COUNT(DISTINCT s.user_id) FROM subscriptions s WHERE s.status<>'cancelled' AND NOT EXISTS (SELECT 1 FROM subscriptions x WHERE x.user_id=s.user_id AND x.status IN ('active','suspended') AND x.starts_at<=? AND x.ends_at>?)", [$n, $n]);
    $stats = [
        'کل کاربران' => (int)val('SELECT COUNT(*) FROM users'),
        'کاربران فعال' => (int)val("SELECT COUNT(*) FROM users WHERE status='active'"),
        'کاربران مسدود' => (int)val("SELECT COUNT(*) FROM users WHERE status='blocked'"),
        'اشتراک‌های فعال' => $cnt(),
        'اشتراک رایگان فعال' => $cnt('free'),
        'اشتراک آزمایشی فعال' => $cnt('trial'),
        'اشتراک خریداری‌شده فعال' => $cnt('paid'),
        'اشتراک‌های منقضی‌شده' => $expired,
        'تراکنش‌های موفق' => (int)val("SELECT COUNT(*) FROM payments WHERE status='paid'"),
    ];
    $b = '<div class="stats">';
    foreach ($stats as $k => $v) $b .= '<div class="stat"><span class="muted">' . $k . '</span><b>' . en_to_fa((string)$v) . '</b></div>';
    $b .= '<div class="stat"><span class="muted">مجموع درآمد</span><b>' . money((int)val("SELECT COALESCE(SUM(amount),0) FROM payments WHERE status='paid'")) . '</b></div></div>';
    // نمودار فروش ۶ ماه شمسی اخیر
    $t = to_tehran($n);
    [$cy, $cm] = g2j((int)$t->format('Y'), (int)$t->format('n'), (int)$t->format('j'));
    $buckets = [];
    for ($i = 5; $i >= 0; $i--) {
        $m = $cm - $i;
        $y = $cy;
        while ($m < 1) {
            $m += 12;
            $y--;
        }
        $buckets["$y-$m"] = 0;
    }
    foreach (rows("SELECT paid_at, amount FROM payments WHERE status='paid' AND paid_at>=?", [add_days($n, -210)]) as $p) {
        $d = to_tehran($p['paid_at']);
        [$y, $m] = g2j((int)$d->format('Y'), (int)$d->format('n'), (int)$d->format('j'));
        if (isset($buckets["$y-$m"])) $buckets["$y-$m"] += (int)$p['amount'];
    }
    $max = max(1, max($buckets));
    $svg = '<svg viewBox="0 0 600 220" style="width:100%;max-width:640px" role="img" aria-label="نمودار فروش اشتراک">';
    $x = 590;
    foreach ($buckets as $k => $v) {
        [$y, $m] = explode('-', $k);
        $h = (int)round(150 * $v / $max);
        $x -= 90;
        $svg .= '<rect x="' . $x . '" y="' . (170 - $h) . '" width="60" height="' . $h . '" rx="6" fill="var(--primary)"/>'
            . '<text x="' . ($x + 30) . '" y="192" text-anchor="middle" font-size="12" fill="var(--muted)">' . J_MONTHS[(int)$m] . '</text>'
            . '<text x="' . ($x + 30) . '" y="' . (164 - $h) . '" text-anchor="middle" font-size="11" fill="var(--text)">' . ($v ? en_to_fa(number_format((int)round($v / 1000))) . ' هزار' : '') . '</text>';
    }
    $b .= '<h2 class="sec">نمودار فروش اشتراک (تومان، ۶ ماه اخیر)</h2><div class="card">' . $svg . '</svg></div>';
    layout('داشبورد', $b, '/');
}

if ($path === '/users') {
    $qv = trim(fa_to_en((string)($_GET['q'] ?? '')));
    $st = (string)($_GET['s'] ?? '');
    $page = max(1, (int)($_GET['page'] ?? 1));
    $per = 25;
    $w = '1=1';
    $a = [];
    if ($qv !== '') {
        $digits = preg_replace('/[^0-9]/', '', $qv);
        $like = '%' . str_replace(['%', '_'], ['\\%', '\\_'], str_replace(['ي', 'ك'], ['ی', 'ک'], $qv)) . '%';
        if ($digits !== '') {
            $w .= ' AND (phone LIKE ? OR full_name LIKE ?)';
            array_push($a, '%' . $digits . '%', $like);
        } else {
            $w .= ' AND full_name LIKE ?';
            $a[] = $like;
        }
    }
    if (in_array($st, ['active', 'blocked'], true)) {
        $w .= ' AND status=?';
        $a[] = $st;
    }
    $total = (int)val("SELECT COUNT(*) FROM users WHERE $w", $a);
    $list = rows("SELECT * FROM users WHERE $w ORDER BY id DESC LIMIT $per OFFSET " . (($page - 1) * $per), $a);
    $b = '<form class="row" method="get"><div><label>جست‌وجوی نام یا شماره</label><input name="q" value="' . e($qv) . '" dir="ltr"></div><div><label>وضعیت حساب</label><select name="s"><option value="">همه</option><option value="active"' . ($st === 'active' ? ' selected' : '') . '>فعال</option><option value="blocked"' . ($st === 'blocked' ? ' selected' : '') . '>مسدود</option></select></div><div><button class="btn">جست‌وجو</button></div></form><br>'
        . '<div class="tablewrap"><table><tr><th>نام و نام خانوادگی</th><th>شماره موبایل</th><th>تاریخ ثبت‌نام</th><th>حساب</th><th>اشتراک</th><th>پایان اشتراک</th></tr>';
    foreach ($list as $u) {
        $s = sub_status((int)$u['id']);
        $b .= '<tr><td><a href="/admin/users/' . $u['id'] . '">' . ($u['full_name'] !== null && $u['full_name'] !== '' ? e($u['full_name']) : '<span class="muted">—</span>') . '</a></td><td dir="ltr">' . e($u['phone']) . '</td><td>' . jdate($u['created_at']) . '</td><td>' . badge($u['status']) . '</td><td>' . badge($s['status']) . ($s['type'] ? ' ' . $TYPE[$s['type']] : '') . '</td><td>' . jdate($s['ends_at'], false) . '</td></tr>';
    }
    if (!$list) $b .= '<tr><td colspan="6" class="muted">موردی یافت نشد.</td></tr>';
    layout('کاربران', $b . '</table></div>' . pager($total, $per, $page, 'q=' . urlencode($qv) . '&s=' . urlencode($st) . '&'), '/users');
}

if (preg_match('#^/users/(\d+)$#', $path, $m)) {
    $uid = (int)$m[1];
    $u = row('SELECT * FROM users WHERE id=?', [$uid]) ?? (function () {
        http_response_code(404);
        exit('کاربر یافت نشد.');
    })();
    if ($isPost) {
        $act = (string)($_POST['act'] ?? '');
        $days = (int)($_POST['days'] ?? 0);
        $note = mb_substr(trim((string)($_POST['note'] ?? '')), 0, 200);
        switch ($act) {
            case 'rename':
                $nn = clean_full_name((string)($_POST['name'] ?? ''));
                if ($nn === null) {
                    flash_set(bad('نام نامعتبر است (فقط حروف، حداقل ۳ کاراکتر).'));
                    break;
                }
                q('UPDATE users SET full_name=? WHERE id=?', [$nn, $uid]);
                alog('user_rename', "user:$uid");
                flash_set(ok('نام ذخیره شد.'));
                break;
            case 'block':
                q("UPDATE users SET status='blocked' WHERE id=?", [$uid]);
                alog('user_block', "user:$uid");
                flash_set(ok('کاربر مسدود شد.'));
                break;
            case 'unblock':
                q("UPDATE users SET status='active' WHERE id=?", [$uid]);
                alog('user_unblock', "user:$uid");
                flash_set(ok('مسدودیت برداشته شد.'));
                break;
            case 'grant':
                $type = in_array($_POST['type'] ?? '', ['free', 'trial'], true) ? $_POST['type'] : 'free';
                if ($days < 1 || $days > 3650) {
                    flash_set(bad('تعداد روز باید بین ۱ تا ۳۶۵۰ باشد.'));
                    break;
                }
                sub_grant($uid, $type, 'admin', $days, adminId: (int)$A['id'], note: $note ?: null);
                alog('sub_grant', "user:$uid", "$type $days days");
                flash_set(ok('اشتراک ثبت شد.'));
                break;
            case 'cancel':
                q("UPDATE subscriptions SET status='cancelled' WHERE user_id=? AND status IN ('active','suspended') AND ends_at>?", [$uid, now()]);
                alog('sub_cancel', "user:$uid");
                flash_set(ok('اشتراک‌های جاری لغو شد.'));
                break;
            case 'suspend':
                q("UPDATE subscriptions SET status='suspended' WHERE user_id=? AND status='active' AND ends_at>?", [$uid, now()]);
                alog('sub_suspend', "user:$uid");
                flash_set(ok('اشتراک متوقف شد.'));
                break;
            case 'resume':
                q("UPDATE subscriptions SET status='active' WHERE user_id=? AND status='suspended'", [$uid]);
                alog('sub_resume', "user:$uid");
                flash_set(ok('اشتراک از سر گرفته شد.'));
                break;
            case 'reset_devices':
                q('DELETE FROM user_devices WHERE user_id=?', [$uid]);
                q('UPDATE api_tokens SET revoked_at=? WHERE user_id=? AND revoked_at IS NULL', [now(), $uid]);
                alog('devices_reset', "user:$uid");
                flash_set(ok('دستگاه‌ها بازنشانی شد؛ کاربر باید دوباره وارد شود.'));
                break;
        }
        go("/users/$uid");
    }
    $s = sub_status($uid);
    $b = '<div class="stats"><div class="stat"><span class="muted">نام</span><b>' . ($u['full_name'] ? e($u['full_name']) : '—') . '</b></div><div class="stat"><span class="muted">شماره موبایل</span><b dir="ltr">' . e(en_to_fa($u['phone'])) . '</b></div><div class="stat"><span class="muted">حساب</span><b>' . badge($u['status']) . '</b></div>'
        . '<div class="stat"><span class="muted">اشتراک</span><b>' . badge($s['status']) . '</b></div><div class="stat"><span class="muted">پایان اشتراک</span><b>' . jdate($s['ends_at'], false) . '</b></div>'
        . '<div class="stat"><span class="muted">ثبت‌نام</span><b>' . jdate($u['created_at'], false) . '</b></div><div class="stat"><span class="muted">آخرین ورود</span><b>' . jdate($u['last_login_at']) . '</b></div></div>';
    $btn = fn(string $act, string $label, string $cls = 'ghost', string $conf = '') => '<form method="post" class="inline">' . csrf_field() . '<input type="hidden" name="act" value="' . $act . '"><button class="btn small ' . $cls . '"' . ($conf ? ' onclick="return confirm(\'' . $conf . '\')"' : '') . '>' . $label . '</button></form> ';
    $b .= '<div class="card"><h3>عملیات</h3><form method="post" class="row" style="margin-bottom:10px">' . csrf_field() . '<input type="hidden" name="act" value="rename"><div><label>نام و نام خانوادگی</label><input name="name" maxlength="100" value="' . e((string)$u['full_name']) . '"></div><div><button class="btn small">ذخیره نام</button></div></form><p>' . ($u['status'] === 'active' ? $btn('block', 'مسدودسازی کاربر', 'danger', 'کاربر مسدود شود؟') : $btn('unblock', 'رفع مسدودیت', ''))
        . $btn('suspend', 'توقف اشتراک') . $btn('resume', 'از سرگیری اشتراک') . $btn('cancel', 'لغو اشتراک جاری', 'danger', 'اشتراک‌های جاری لغو شود؟') . $btn('reset_devices', 'بازنشانی دستگاه‌ها', '', 'دستگاه ثبت‌شده حذف شود؟') . '</p>'
        . '<form method="post" class="row">' . csrf_field() . '<input type="hidden" name="act" value="grant"><div><label>نوع</label><select name="type"><option value="free">رایگان</option><option value="trial">آزمایشی</option></select></div>'
        . '<div><label>تعداد روز</label><input name="days" type="number" min="1" max="3650" required></div><div><label>یادداشت</label><input name="note" maxlength="200"></div><div><button class="btn small">صدور / تمدید دستی</button></div></form></div>';
    $b .= '<h2 class="sec">تاریخچه اشتراک‌ها</h2><div class="tablewrap"><table><tr><th>نوع</th><th>منبع</th><th>شروع</th><th>پایان</th><th>وضعیت</th><th>یادداشت</th></tr>';
    $src = ['auto' => 'خودکار', 'admin' => 'مدیر', 'payment' => 'خرید'];
    foreach (rows('SELECT * FROM subscriptions WHERE user_id=? ORDER BY id DESC', [$uid]) as $r) $b .= '<tr><td>' . $TYPE[$r['type']] . '</td><td>' . $src[$r['source']] . '</td><td>' . jdate($r['starts_at'], false) . '</td><td>' . jdate($r['ends_at'], false) . '</td><td>' . badge($r['status']) . '</td><td>' . e((string)$r['note']) . '</td></tr>';
    $b .= '</table></div><h2 class="sec">پرداخت‌ها</h2><div class="tablewrap"><table><tr><th>تاریخ</th><th>پلن</th><th>مبلغ</th><th>درگاه</th><th>وضعیت</th><th>شناسه پیگیری</th></tr>';
    foreach (rows('SELECT p.*, pl.title FROM payments p JOIN plans pl ON pl.id=p.plan_id WHERE p.user_id=? ORDER BY p.id DESC', [$uid]) as $r) $b .= '<tr><td>' . jdate($r['created_at']) . '</td><td>' . e($r['title']) . '</td><td>' . money((int)$r['amount']) . '</td><td>' . ($GW[$r['gateway']] ?? '') . '</td><td>' . badge($r['status']) . '</td><td dir="ltr">' . e($r['tracking_code']) . '</td></tr>';
    $b .= '</table></div><h2 class="sec">دستگاه‌ها</h2><div class="tablewrap"><table><tr><th>نام دستگاه</th><th>ثبت</th><th>وضعیت</th></tr>';
    foreach (rows('SELECT * FROM user_devices WHERE user_id=? ORDER BY id DESC', [$uid]) as $r) $b .= '<tr><td>' . e((string)$r['device_name']) . '</td><td>' . jdate($r['bound_at']) . '</td><td>' . ($r['unbound_at'] ? 'جایگزین شده' : badge('active')) . '</td></tr>';
    layout('کاربر ' . ($u['full_name'] ? $u['full_name'] . ' — ' : '') . en_to_fa($u['phone']), $b . '</table></div>', '/users');
}

if ($path === '/subscriptions') {
    $f = (string)($_GET['f'] ?? 'active');
    $page = max(1, (int)($_GET['page'] ?? 1));
    $per = 25;
    $n = now();
    if ($f === 'expired') {
        $from = "FROM users u JOIN subscriptions s ON s.user_id=u.id AND s.status<>'cancelled' WHERE NOT EXISTS (SELECT 1 FROM subscriptions x WHERE x.user_id=u.id AND x.status IN ('active','suspended') AND x.starts_at<=? AND x.ends_at>?)";
        $total = (int)val("SELECT COUNT(DISTINCT u.id) $from", [$n, $n]);
        $list = rows("SELECT u.id, u.phone, '' AS type, MAX(s.ends_at) AS ends_at $from GROUP BY u.id ORDER BY ends_at DESC LIMIT $per OFFSET " . (($page - 1) * $per), [$n, $n]);
    } else {
        $tw = in_array($f, ['free', 'trial', 'paid'], true) ? " AND s.type='$f'" : '';
        $stat = $f === 'suspended' ? 'suspended' : 'active';
        $from = "FROM users u JOIN subscriptions s ON s.user_id=u.id WHERE s.status='$stat' AND s.starts_at<=? AND s.ends_at>?$tw";
        $total = (int)val("SELECT COUNT(DISTINCT u.id) $from", [$n, $n]);
        $list = rows("SELECT u.id, u.phone, MAX(s.type) AS type, MAX(s.ends_at) AS ends_at $from GROUP BY u.id ORDER BY ends_at ASC LIMIT $per OFFSET " . (($page - 1) * $per), [$n, $n]);
    }
    $tabs = ['active' => 'فعال', 'free' => 'رایگان', 'trial' => 'آزمایشی', 'paid' => 'خریداری‌شده', 'suspended' => 'متوقف', 'expired' => 'منقضی‌شده'];
    $b = '<p>';
    foreach ($tabs as $k => $v) $b .= '<a class="btn small' . ($f === $k ? '' : ' ghost') . '" href="?f=' . $k . '">' . $v . '</a> ';
    $b .= '</p><div class="tablewrap"><table><tr><th>شماره موبایل</th><th>نوع</th><th>پایان اشتراک</th></tr>';
    foreach ($list as $r) $b .= '<tr><td dir="ltr"><a href="/admin/users/' . $r['id'] . '">' . e($r['phone']) . '</a></td><td>' . ($TYPE[$r['type']] ?? '—') . '</td><td>' . jdate($r['ends_at'], false) . '</td></tr>';
    if (!$list) $b .= '<tr><td colspan="3" class="muted">موردی یافت نشد.</td></tr>';
    layout('اشتراک‌ها', $b . '</table></div>' . pager($total, $per, $page, 'f=' . urlencode($f) . '&'), '/subscriptions');
}

if ($path === '/plans') {
    if ($isPost) {
        need_super();
        $act = (string)($_POST['act'] ?? '');
        $id = (int)($_POST['id'] ?? 0);
        $title = mb_substr(trim((string)($_POST['title'] ?? '')), 0, 120);
        $desc = mb_substr(trim((string)($_POST['description'] ?? '')), 0, 255);
        $price = (int)fa_to_en((string)($_POST['price'] ?? '0'));
        $days = (int)($_POST['days'] ?? 0);
        $sort = (int)($_POST['sort'] ?? 0);
        $active = isset($_POST['active']) ? 1 : 0;
        if (in_array($act, ['create', 'save'], true) && ($title === '' || $price < 1000 || $days < 1 || $days > 3650)) {
            flash_set(bad('عنوان، قیمت (حداقل ۱٬۰۰۰ تومان) و مدت (۱ تا ۳۶۵۰ روز) را درست وارد کنید.'));
            go('/plans');
        }
        if ($act === 'create') {
            q('INSERT INTO plans(title,description,price,duration_days,is_active,sort_order,created_at) VALUES(?,?,?,?,?,?,?)', [$title, $desc, $price, $days, $active, $sort, now()]);
            alog('plan_create', 'plan:' . insert_id(), $title);
            flash_set(ok('پلن ساخته شد.'));
        } elseif ($act === 'save') {
            q('UPDATE plans SET title=?, description=?, price=?, duration_days=?, is_active=?, sort_order=? WHERE id=?', [$title, $desc, $price, $days, $active, $sort, $id]);
            alog('plan_edit', "plan:$id");
            flash_set(ok('پلن ذخیره شد.'));
        } elseif ($act === 'delete') {
            $used = (int)val('SELECT (SELECT COUNT(*) FROM payments WHERE plan_id=?) + (SELECT COUNT(*) FROM subscriptions WHERE plan_id=?)', [$id, $id]);
            if ($used) {
                q('UPDATE plans SET is_active=0 WHERE id=?', [$id]);
                flash_set(ok('این پلن قبلاً استفاده شده و حذف نمی‌شود؛ غیرفعال شد.'));
            } else {
                q('DELETE FROM plans WHERE id=?', [$id]);
                flash_set(ok('پلن حذف شد.'));
            }
            alog('plan_delete', "plan:$id");
        }
        go('/plans');
    }
    $b = '<div class="card"><h3>پلن جدید</h3><form method="post" class="row">' . csrf_field() . '<input type="hidden" name="act" value="create"><input type="hidden" name="active" value="1">'
        . '<div><label>عنوان</label><input name="title" required></div><div><label>قیمت (تومان)</label><input name="price" inputmode="numeric" required></div><div><label>مدت (روز)</label><input name="days" type="number" required></div>'
        . '<div><label>توضیح</label><input name="description"></div><div><label>ترتیب</label><input name="sort" type="number" value="0"></div><div><button class="btn small">افزودن</button></div></form></div><h2 class="sec">پلن‌ها</h2>';
    foreach (rows('SELECT * FROM plans ORDER BY sort_order, id') as $p) {
        $b .= '<form method="post" class="card row" style="margin-bottom:10px">' . csrf_field() . '<input type="hidden" name="id" value="' . $p['id'] . '">'
            . '<div><label>عنوان</label><input name="title" value="' . e($p['title']) . '"></div><div><label>قیمت (تومان)</label><input name="price" value="' . $p['price'] . '"></div><div><label>مدت (روز)</label><input name="days" type="number" value="' . $p['duration_days'] . '"></div>'
            . '<div><label>توضیح</label><input name="description" value="' . e((string)$p['description']) . '"></div><div><label>ترتیب</label><input name="sort" type="number" value="' . $p['sort_order'] . '"></div>'
            . '<div><label><input type="checkbox" name="active" value="1"' . ($p['is_active'] ? ' checked' : '') . '> فعال</label>'
            . '<button class="btn small" name="act" value="save">ذخیره</button> <button class="btn small danger" name="act" value="delete" onclick="return confirm(\'پلن حذف یا غیرفعال شود؟\')">حذف</button></div></form>';
    }
    layout('پلن‌های اشتراک', $b, '/plans');
}

if ($path === '/payments') {
    $qv = trim((string)($_GET['q'] ?? ''));
    $st = (string)($_GET['s'] ?? '');
    $page = max(1, (int)($_GET['page'] ?? 1));
    $per = 30;
    $w = '1=1';
    $a = [];
    if ($qv !== '') {
        $w .= ' AND (p.tracking_code LIKE ? OR p.authority LIKE ? OR p.ref_id LIKE ? OR u.phone LIKE ?)';
        $like = '%' . str_replace(['%', '_'], ['\\%', '\\_'], fa_to_en($qv)) . '%';
        array_push($a, $like, $like, $like, $like);
    }
    if (in_array($st, ['paid', 'pending', 'failed'], true)) {
        $w .= ' AND p.status=?';
        $a[] = $st;
    }
    $total = (int)val("SELECT COUNT(*) FROM payments p JOIN users u ON u.id=p.user_id WHERE $w", $a);
    $sum = (int)val("SELECT COALESCE(SUM(p.amount),0) FROM payments p JOIN users u ON u.id=p.user_id WHERE $w AND p.status='paid'", $a);
    $list = rows("SELECT p.*, u.phone, pl.title FROM payments p JOIN users u ON u.id=p.user_id JOIN plans pl ON pl.id=p.plan_id WHERE $w ORDER BY p.id DESC LIMIT $per OFFSET " . (($page - 1) * $per), $a);
    $opt = fn($v, $l) => '<option value="' . $v . '"' . ($st === $v ? ' selected' : '') . '>' . $l . '</option>';
    $b = '<form class="row" method="get"><div><label>جست‌وجو (شناسه پیگیری، Authority، کد مرجع، موبایل)</label><input name="q" value="' . e($qv) . '" dir="ltr"></div><div><label>وضعیت</label><select name="s">' . $opt('', 'همه') . $opt('paid', 'موفق') . $opt('pending', 'در انتظار') . $opt('failed', 'ناموفق') . '</select></div><div><button class="btn">فیلتر</button></div></form>'
        . '<p class="muted">مجموع پرداخت‌های موفق در این فیلتر: <b>' . money($sum) . '</b></p><div class="tablewrap"><table><tr><th>تاریخ</th><th>کاربر</th><th>پلن</th><th>مبلغ</th><th>درگاه</th><th>وضعیت</th><th>شناسه پیگیری</th><th>کد مرجع</th><th>تاریخ پرداخت</th></tr>';
    foreach ($list as $p) $b .= '<tr><td>' . jdate($p['created_at']) . '</td><td dir="ltr"><a href="/admin/users/' . $p['user_id'] . '">' . e($p['phone']) . '</a></td><td>' . e($p['title']) . '</td><td>' . money((int)$p['amount']) . '</td><td>' . ($GW[$p['gateway']] ?? '') . '</td><td>' . badge($p['status']) . '</td><td dir="ltr">' . e($p['tracking_code']) . '</td><td dir="ltr">' . e((string)$p['ref_id']) . '</td><td>' . jdate($p['paid_at']) . '</td></tr>';
    if (!$list) $b .= '<tr><td colspan="9" class="muted">تراکنشی یافت نشد.</td></tr>';
    layout('پرداخت‌ها', $b . '</table></div>' . pager($total, $per, $page, 'q=' . urlencode($qv) . '&s=' . urlencode($st) . '&'), '/payments');
}

if ($path === '/sms-logs') {
    $only = ($_GET['f'] ?? '') === 'failed';
    $b = '<p><a class="btn small' . ($only ? ' ghost' : '') . '" href="?">همه</a> <a class="btn small' . ($only ? '' : ' ghost') . '" href="?f=failed">فقط خطاها</a></p><div class="tablewrap"><table><tr><th>تاریخ</th><th>نوع</th><th>تعداد گیرنده</th><th>وضعیت</th><th>خطا</th></tr>';
    foreach (rows('SELECT * FROM sms_logs ' . ($only ? "WHERE status='failed' " : '') . 'ORDER BY id DESC LIMIT 200') as $r) $b .= '<tr><td>' . jdate($r['created_at']) . '</td><td>' . ($r['kind'] === 'otp' ? 'کد تأیید' : 'باشگاه مشتریان') . '</td><td>' . en_to_fa((string)$r['recipients_count']) . '</td><td>' . badge($r['status']) . '</td><td>' . e((string)$r['error']) . '</td></tr>';
    layout('گزارش پیامک‌ها', $b . '</table></div>', '/sms-logs');
}

if ($path === '/logs') {
    $b = '<div class="tablewrap"><table><tr><th>تاریخ</th><th>مدیر</th><th>عملیات</th><th>هدف</th><th>جزئیات</th><th>IP</th></tr>';
    foreach (rows('SELECT l.*, a.username FROM admin_logs l LEFT JOIN admins a ON a.id=l.admin_id ORDER BY l.id DESC LIMIT 200') as $r) $b .= '<tr><td>' . jdate($r['created_at']) . '</td><td>' . e((string)$r['username']) . '</td><td>' . e($r['action']) . '</td><td dir="ltr">' . e((string)$r['target']) . '</td><td>' . e((string)$r['details']) . '</td><td dir="ltr">' . e((string)$r['ip']) . '</td></tr>';
    layout('فعالیت‌های مدیریتی', $b . '</table></div>', '/logs');
}

if ($path === '/settings') {
    need_super();
    $sections = [
        'general' => ['عمومی', ['site_name' => 'نام سایت', 'support_text' => 'متن پشتیبانی (فوتر سایت)', 'download_url' => 'لینک دانلود نرم‌افزار', 'app_latest_version' => 'آخرین نسخه نرم‌افزار', 'app_min_version' => 'حداقل نسخه مجاز']],
        'trial' => ['اشتراک آزمایشی', ['trial_enabled' => ['چک', 'فعال‌سازی خودکار پس از ثبت‌نام'], 'trial_days' => 'مدت (روز)']],
        'ippanel' => ['IPPanel (پیامک)', ['ippanel_api_key' => ['رمز', 'کلید API'], 'ippanel_from_number' => 'شماره ارسال‌کننده (مثلاً +983000505)', 'ippanel_otp_pattern' => 'کد پترن OTP', 'ippanel_otp_param' => 'نام متغیر کد در پترن']],
        'gateways' => ['درگاه‌های پرداخت', [
            'active_gateway' => ['انتخاب', 'درگاه فعال'],
            'gateway_zarinpal_enabled' => ['چک', 'زرین‌پال فعال باشد'],
            'zarinpal_merchant' => ['رمز', 'مرچنت‌کد زرین‌پال'],
            'zarinpal_sandbox' => ['چک', 'حالت Sandbox زرین‌پال'],
            'gateway_zibal_enabled' => ['چک', 'زیبال فعال باشد'],
            'zibal_merchant' => ['رمز', 'مرچنت زیبال'],
            'zibal_test_mode' => ['چک', 'حالت تست زیبال (merchant=zibal)']
        ]],
        'club' => ['پیامک باشگاه مشتریان', ['club_sms_enabled' => ['چک', 'ارسال پیامک فعال باشد'], 'club_sms_daily_limit' => 'سقف ارسال روزانه هر کاربر', 'club_sms_suffix' => 'متن انتهای پیامک (مثلاً راهنمای لغو دریافت)']],
        'security' => ['امنیت نرم‌افزار', ['device_binds_30d' => 'حداکثر دفعات ثبت دستگاه در ۳۰ روز', 'token_ttl_days' => 'اعتبار توکن ورود (روز)']],
    ];
    if ($isPost) {
        $sec = (string)($_POST['section'] ?? '');
        if (isset($sections[$sec])) {
            $err = '';
            foreach ($sections[$sec][1] as $k => $meta) {
                $type = is_array($meta) ? $meta[0] : 'متن';
                $v = trim((string)($_POST[$k] ?? ''));
                if ($type === 'چک') {
                    set_setting($k, isset($_POST[$k]) ? '1' : '0');
                    continue;
                }
                if ($type === 'رمز') {
                    if ($v !== '') set_setting($k, $v);
                    continue;
                }
                if (in_array($k, ['trial_days', 'club_sms_daily_limit', 'device_binds_30d', 'token_ttl_days'], true) && (!ctype_digit($v) || (int)$v < 0 || (int)$v > 100000)) {
                    $err = 'مقادیر عددی نامعتبر است.';
                    continue;
                }
                if ($k === 'active_gateway' && !in_array($v, ['zarinpal', 'zibal'], true)) {
                    $err = 'درگاه نامعتبر است.';
                    continue;
                }
                if ($k === 'ippanel_from_number' && $v !== '' && !preg_match('/^\+\d{6,15}$/', $v)) {
                    $err = 'شماره ارسال‌کننده باید به‌صورت بین‌المللی (مثلاً +983000505) باشد.';
                    continue;
                }
                if ($k === 'download_url' && $v !== '' && !preg_match('#^https?://#i', $v)) {
                    $err = 'لینک دانلود باید با http یا https شروع شود.';
                    continue;
                }
                set_setting($k, $v);
            }
            alog('settings_save', $sec);
            flash_set($err ? bad($err) : ok('تنظیمات ذخیره شد.'));
        }
        go('/settings');
    }
    $S = settings_all(true);
    $b = '<p class="muted">آدرس بازگشت از درگاه‌ها: <span dir="ltr">' . e(rtrim((string)cfg('site_url'), '/')) . '/pay/callback</span> — آدرس API نرم‌افزار: <span dir="ltr">' . e(rtrim((string)cfg('site_url'), '/')) . '/api/v1/</span></p>';
    foreach ($sections as $sk => [$label, $fields]) {
        $b .= '<form method="post" class="card" style="margin-bottom:14px"><h3>' . $label . '</h3>' . csrf_field() . '<input type="hidden" name="section" value="' . $sk . '">';
        foreach ($fields as $k => $meta) {
            $type = is_array($meta) ? $meta[0] : 'متن';
            $lab = is_array($meta) ? $meta[1] : $meta;
            if ($type === 'چک') $b .= '<label><input type="checkbox" name="' . $k . '" value="1"' . (($S[$k] ?? '0') === '1' ? ' checked' : '') . '> ' . $lab . '</label>';
            elseif ($type === 'رمز') $b .= '<label>' . $lab . '</label><input type="password" name="' . $k . '" dir="ltr" autocomplete="off" placeholder="' . (($S[$k] ?? '') !== '' ? '•••••••• (ذخیره شده؛ برای تغییر مقدار جدید وارد کنید)' : 'وارد نشده') . '">';
            elseif ($type === 'انتخاب') $b .= '<label>' . $lab . '</label><select name="' . $k . '"><option value="zarinpal"' . ($S[$k] === 'zarinpal' ? ' selected' : '') . '>زرین‌پال</option><option value="zibal"' . ($S[$k] === 'zibal' ? ' selected' : '') . '>زیبال</option></select>';
            else $b .= '<label>' . $lab . '</label><input name="' . $k . '" value="' . e($S[$k] ?? '') . '"' . (in_array($k, ['download_url', 'ippanel_from_number', 'ippanel_otp_pattern', 'ippanel_otp_param', 'app_latest_version', 'app_min_version'], true) ? ' dir="ltr"' : '') . '>';
        }
        $b .= '<button class="btn small">ذخیره</button></form>';
    }
    layout('تنظیمات', $b, '/settings');
}

if ($path === '/admins') {
    need_super();
    if ($isPost) {
        $act = (string)($_POST['act'] ?? '');
        if ($act === 'create') {
            $un = trim((string)($_POST['username'] ?? ''));
            $pw = (string)($_POST['password'] ?? '');
            $role = ($_POST['role'] ?? '') === 'super' ? 'super' : 'support';
            if (!preg_match('/^[A-Za-z0-9_.]{3,40}$/', $un) || mb_strlen($pw) < 10) flash_set(bad('نام کاربری (۳ تا ۴۰ حرف لاتین/عدد) و رمز (حداقل ۱۰ کاراکتر) لازم است.'));
            elseif (val('SELECT COUNT(*) FROM admins WHERE username=?', [$un])) flash_set(bad('این نام کاربری وجود دارد.'));
            else {
                q('INSERT INTO admins(username,password_hash,role,created_at) VALUES(?,?,?,?)', [$un, password_hash($pw, PASSWORD_DEFAULT), $role, now()]);
                alog('admin_create', $un);
                flash_set(ok('مدیر ساخته شد.'));
            }
        } elseif ($act === 'toggle' && (int)$_POST['id'] !== (int)$A['id']) {
            q("UPDATE admins SET status=IF(status='active','disabled','active') WHERE id=?", [(int)$_POST['id']]);
            alog('admin_toggle', 'admin:' . (int)$_POST['id']);
            flash_set(ok('وضعیت مدیر تغییر کرد.'));
        } elseif ($act === 'password') {
            $pw = (string)($_POST['password'] ?? '');
            $id = (int)($_POST['id'] ?? 0);
            if (mb_strlen($pw) < 10) flash_set(bad('رمز باید حداقل ۱۰ کاراکتر باشد.'));
            else {
                q('UPDATE admins SET password_hash=?, failed_attempts=0, locked_until=NULL WHERE id=?', [password_hash($pw, PASSWORD_DEFAULT), $id]);
                alog('admin_password', "admin:$id");
                flash_set(ok('رمز تغییر کرد.'));
            }
        }
        go('/admins');
    }
    $b = '<div class="card"><h3>مدیر جدید</h3><form method="post" class="row">' . csrf_field() . '<input type="hidden" name="act" value="create"><div><label>نام کاربری</label><input name="username" dir="ltr" required></div><div><label>رمز (حداقل ۱۰ کاراکتر)</label><input type="password" name="password" dir="ltr" required></div><div><label>نقش</label><select name="role"><option value="support">پشتیبان (بدون تنظیمات)</option><option value="super">مدیر کل</option></select></div><div><button class="btn small">افزودن</button></div></form></div>'
        . '<h2 class="sec">مدیران</h2><div class="tablewrap"><table><tr><th>نام کاربری</th><th>نقش</th><th>وضعیت</th><th>آخرین ورود</th><th>عملیات</th></tr>';
    foreach (rows('SELECT * FROM admins ORDER BY id') as $r) {
        $b .= '<tr><td dir="ltr">' . e($r['username']) . '</td><td>' . ($r['role'] === 'super' ? 'مدیر کل' : 'پشتیبان') . '</td><td>' . badge($r['status'] === 'active' ? 'active' : 'blocked') . '</td><td>' . jdate($r['last_login_at']) . '</td><td>'
            . ((int)$r['id'] !== (int)$A['id'] ? '<form method="post" class="inline">' . csrf_field() . '<input type="hidden" name="act" value="toggle"><input type="hidden" name="id" value="' . $r['id'] . '"><button class="btn small ghost">فعال/غیرفعال</button></form> ' : '')
            . '<form method="post" class="inline">' . csrf_field() . '<input type="hidden" name="act" value="password"><input type="hidden" name="id" value="' . $r['id'] . '"><input type="password" name="password" placeholder="رمز جدید" dir="ltr" style="width:150px;display:inline-block"> <button class="btn small ghost">تغییر رمز</button></form></td></tr>';
    }
    layout('مدیران', $b . '</table></div>', '/admins');
}

http_response_code(404);
layout('یافت نشد', '<p>صفحه مورد نظر وجود ندارد.</p>');
