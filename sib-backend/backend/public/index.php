<?php
declare(strict_types=1);
require __DIR__ . '/../app/services.php';

security_headers();
header('Content-Type: text/html; charset=utf-8');
set_exception_handler(function (Throwable $e) {
    app_log('error', 'web exception: ' . $e->getMessage(), ['file' => $e->getFile(), 'line' => $e->getLine()]);
    http_response_code(500);
    echo cfg('debug') ? '<pre>' . e((string)$e) . '</pre>' : 'خطای داخلی سرور. لطفاً بعداً تلاش کنید.';
    exit;
});
start_session('acc_sid');
rebase_output();

/* ---------- مسیریابی ---------- */
$path = '/' . trim((string)parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH), '/');
$base = rtrim(dirname($_SERVER['SCRIPT_NAME'] ?? ''), '/');
if ($base !== '' && str_starts_with($path, $base)) $path = '/' . trim(substr($path, strlen($base)), '/');
if ($path === '/index.php') $path = '/';
$isPost = ($_SERVER['REQUEST_METHOD'] ?? '') === 'POST';
if ($isPost) csrf_check();

/* ---------- قالب ---------- */
function page(string $title, string $body, string $nav = ''): never {
    $site = e(setting('site_name'));
    $user = !empty($_SESSION['uid']);
    echo '<!doctype html><html lang="fa" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
       . "<title>" . e($title) . " | $site</title><link rel=\"stylesheet\" href=\"/assets/style.css\"></head><body>"
       . '<header class="top"><div class="wrap"><a class="brand" href="/">' . $site . '</a><nav>'
       . ($user ? '<span class="muted">' . e((string)($_SESSION['uname'] ?? '')) . '</span><a href="/panel">پنل کاربری</a><a href="/buy">خرید اشتراک</a><a href="/panel/payments">پرداخت‌ها</a>'
                  . '<form method="post" action="/logout" class="inline">' . csrf_field() . '<button class="link">خروج</button></form>'
                : '<a href="/login">ورود</a><a class="btn small" href="/register">ثبت‌نام</a>')
       . '</nav></div></header><main class="wrap">' . $body . '</main>'
       . '<footer class="wrap muted">' . e(setting('support_text')) . '</footer></body></html>';
    exit;
}
function flash(string $type, string $msg): string { return '<div class="alert ' . $type . '">' . e($msg) . '</div>'; }
function need_login(): array {
    if (empty($_SESSION['uid'])) { redir('/login'); }
    $u = row('SELECT * FROM users WHERE id=?', [$_SESSION['uid']]);
    if (!$u || $u['status'] !== 'active') { session_destroy(); redir('/login'); }
    $_SESSION['uname'] = user_display_name($u);
    return $u;
}
$sLabel = ['active' => 'فعال', 'expired' => 'منقضی‌شده', 'none' => 'بدون اشتراک', 'suspended' => 'متوقف‌شده', 'blocked' => 'مسدود'];
$tLabel = ['trial' => 'آزمایشی', 'free' => 'رایگان', 'paid' => 'خریداری‌شده'];

/* ---------- ثبت‌نام / ورود با OTP ---------- */
function auth_page(string $mode): never {
    $msg = '';
    $title = $mode === 'register' ? 'ثبت‌نام' : 'ورود';
    $step = !empty($_SESSION['otp_phone']) && ($_SESSION['otp_mode'] ?? '') === $mode ? 'code' : 'phone';
    if (($_SERVER['REQUEST_METHOD'] ?? '') === 'POST') {
        $act = $_POST['act'] ?? '';
        if ($act === 'send') {
            $phone = normalize_phone((string)($_POST['phone'] ?? ''));
            $u = $phone ? user_by_phone($phone) : null;
            $fullName = $mode === 'register' ? clean_full_name((string)($_POST['name'] ?? '')) : null;
            if ($mode === 'register' && $fullName === null) $msg = flash('err', 'نام و نام خانوادگی را وارد کنید (فقط حروف، حداقل ۳ کاراکتر).');
            elseif (!$phone) $msg = flash('err', 'شماره موبایل نامعتبر است. فرمت صحیح: 09xxxxxxxxx');
            elseif ($mode === 'register' && $u) $msg = flash('err', 'این شماره قبلاً ثبت‌نام کرده است. از صفحه ورود وارد شوید.');
            elseif ($mode === 'login' && !$u) $msg = flash('err', 'این شماره ثبت‌نام نکرده است. ابتدا ثبت‌نام کنید.');
            elseif ($u && $u['status'] === 'blocked') $msg = flash('err', 'حساب کاربری شما مسدود است.');
            else {
                $r = otp_issue($phone, $mode);
                if ($r['ok']) { $_SESSION['otp_phone'] = $phone; $_SESSION['otp_mode'] = $mode; if ($fullName !== null) $_SESSION['reg_name'] = $fullName; $step = 'code'; $msg = flash('ok', 'کد تأیید به شماره شما پیامک شد.'); }
                else $msg = flash('err', $r['error'] ?? 'خطا');
            }
        } elseif ($act === 'verify' && !empty($_SESSION['otp_phone'])) {
            $phone = $_SESSION['otp_phone'];
            if (!quota_take("otpv:web:" . client_ip() . ":$phone", 10, 900)) { $msg = flash('err', 'تلاش‌های ناموفق زیاد بود. چند دقیقه بعد دوباره امتحان کنید.'); }
            elseif (otp_verify($phone, $mode, (string)($_POST['code'] ?? ''))) {
                $u = user_by_phone($phone);
                if (!$u && $mode === 'register') { $rn = (string)($_SESSION['reg_name'] ?? ''); try { $uid = user_create($phone, $rn !== '' ? $rn : null); } catch (PDOException $e) { $uid = (int)(user_by_phone($phone)['id'] ?? 0); } }
                else $uid = $u ? (int)$u['id'] : 0;
                if ($uid && ($u === null || $u['status'] === 'active')) {
                    session_regenerate_id(true);
                    unset($_SESSION['otp_phone'], $_SESSION['otp_mode'], $_SESSION['reg_name']);
                    $_SESSION['uid'] = $uid;
                    q('UPDATE users SET last_login_at=? WHERE id=?', [now(), $uid]);
                    redir('/panel');
                }
                $msg = flash('err', 'ورود امکان‌پذیر نیست.');
            } else { $msg = flash('err', 'کد تأیید اشتباه یا منقضی شده است.'); $step = 'code'; }
        } elseif ($act === 'back') { unset($_SESSION['otp_phone'], $_SESSION['otp_mode']); $step = 'phone'; }
    }
    $f = '<div class="card narrow"><h1>' . $title . '</h1>' . $msg;
    if ($step === 'phone') {
        $f .= '<form method="post">' . csrf_field() . '<input type="hidden" name="act" value="send">'
            . ($mode === 'register' ? '<label>نام و نام خانوادگی</label><input name="name" maxlength="100" autocomplete="name" value="' . e((string)($_POST['name'] ?? ($_SESSION['reg_name'] ?? ''))) . '" required autofocus>' : '')
            . '<label>شماره موبایل</label><input name="phone" inputmode="numeric" maxlength="14" placeholder="09123456789" dir="ltr" required>'
            . '<button class="btn">ارسال کد تأیید</button></form>'
            . '<p class="muted">' . ($mode === 'register' ? 'قبلاً ثبت‌نام کرده‌اید؟ <a href="/login">ورود</a>' : 'حساب ندارید؟ <a href="/register">ثبت‌نام</a>') . '</p>';
    } else {
        $f .= '<p>کد ارسال‌شده به <b dir="ltr">' . e(en_to_fa($_SESSION['otp_phone'])) . '</b> را وارد کنید.</p>'
            . '<form method="post">' . csrf_field() . '<input type="hidden" name="act" value="verify">'
            . '<input name="code" inputmode="numeric" maxlength="6" dir="ltr" autocomplete="one-time-code" required autofocus>'
            . '<button class="btn">تأیید و ادامه</button></form>'
            . '<form method="post">' . csrf_field() . '<input type="hidden" name="act" value="back"><button class="link">تغییر شماره / ارسال مجدد</button></form>';
    }
    page($title, $f . '</div>');
}

/* ---------- صفحات ---------- */
switch ($path) {
    case '/':
        $plans = rows('SELECT * FROM plans WHERE is_active=1 ORDER BY sort_order, price');
        $b = '<section class="hero"><h1>' . e(setting('site_name')) . '</h1><p>نرم‌افزار حسابداری ساده، سریع و فارسی برای ویندوز. اطلاعات مالی شما فقط روی کامپیوتر خودتان می‌ماند.</p>'
           . '<a class="btn" href="/register">شروع کنید</a></section>';
        if ($plans) {
            $b .= '<h2>پلن‌های اشتراک</h2><div class="grid">';
            foreach ($plans as $p) $b .= '<div class="card"><h3>' . e($p['title']) . '</h3><p class="muted">' . e((string)$p['description']) . '</p><div class="price">' . money((int)$p['price']) . '</div><div class="muted">' . en_to_fa((string)$p['duration_days']) . ' روز</div></div>';
            $b .= '</div>';
        }
        page('صفحه اصلی', $b);

    case '/register': auth_page('register');
    case '/login': auth_page('login');

    case '/logout':
        if ($isPost) { session_destroy(); }
        redir('/');

    case '/panel': {
        $u = need_login();
        $s = sub_status((int)$u['id']);
        $flashMsg = $_SESSION['flash'] ?? ''; unset($_SESSION['flash']);
        $name = trim((string)($u['full_name'] ?? ''));
        $b = '<h1>' . ($name !== '' ? 'سلام ' . e($name) : 'پنل کاربری') . '</h1>' . $flashMsg
           . '<div class="grid"><div class="card"><div class="muted">نام و نام خانوادگی</div><div class="big">' . ($name !== '' ? e($name) : '<span class="muted">ثبت نشده</span>') . '</div>'
           . '<div class="muted" dir="ltr">' . e(en_to_fa($u['phone'])) . '</div></div>'
           . '<div class="card"><div class="muted">وضعیت اشتراک</div><div class="big ' . ($s['status'] === 'active' ? 'okc' : 'errc') . '">' . $sLabel[$s['status']] . '</div>'
           . ($s['type'] ? '<div class="muted">نوع: ' . $tLabel[$s['type']] . '</div>' : '') . '</div>'
           . '<div class="card"><div class="muted">تاریخ پایان</div><div class="big">' . jdate($s['ends_at'], false) . '</div>'
           . ($s['status'] === 'active' ? '<div class="muted">' . en_to_fa((string)$s['days_left']) . ' روز مانده</div>' : '') . '</div></div>'
           . '<p><a class="btn" href="/buy">خرید / تمدید اشتراک</a></p>';
        if (setting('download_url') !== '') $b .= '<p><a class="btn ghost" href="' . e(setting('download_url')) . '">دانلود نرم‌افزار ویندوز</a></p>';
        $b .= '<div class="card narrow" style="margin:18px 0"><h3>' . ($name !== '' ? 'ویرایش نام' : 'ثبت نام شما') . '</h3><form method="post" action="/panel/profile">' . csrf_field()
           . '<label>نام و نام خانوادگی</label><input name="name" maxlength="100" value="' . e($name) . '" required><button class="btn">ذخیره</button></form></div>';
        $b .= '<p class="muted">پس از نصب نرم‌افزار، با همین شماره موبایل و کد پیامکی وارد شوید. هر اشتراک روی یک دستگاه فعال است.</p>';
        page('پنل کاربری', $b);
    }

    case '/panel/profile': {
        $u = need_login();
        if (!$isPost) redir('/panel');
        $name = clean_full_name((string)($_POST['name'] ?? ''));
        if ($name === null) { $_SESSION['flash'] = flash('err', 'نام و نام خانوادگی را فقط با حروف و حداقل ۳ کاراکتر وارد کنید.'); redir('/panel'); }
        q('UPDATE users SET full_name=? WHERE id=?', [$name, $u['id']]);
        $_SESSION['uname'] = $name;
        $_SESSION['flash'] = flash('ok', 'نام شما ذخیره شد.');
        redir('/panel');
    }

    case '/buy': {
        $u = need_login();
        $plans = rows('SELECT * FROM plans WHERE is_active=1 ORDER BY sort_order, price');
        $msg = $_SESSION['flash'] ?? ''; unset($_SESSION['flash']);
        $b = '<h1>خرید اشتراک</h1>' . $msg;
        if (!gateway_active()) $b .= flash('err', 'درگاه پرداخت در حال حاضر فعال نیست.');
        if (!$plans) $b .= '<p class="muted">پلنی برای فروش تعریف نشده است.</p>';
        $b .= '<div class="grid">';
        foreach ($plans as $p) $b .= '<div class="card"><h3>' . e($p['title']) . '</h3><p class="muted">' . e((string)$p['description']) . '</p><div class="price">' . money((int)$p['price']) . '</div><div class="muted">اعتبار: ' . en_to_fa((string)$p['duration_days']) . ' روز</div>'
            . '<form method="post" action="/pay/start">' . csrf_field() . '<input type="hidden" name="plan_id" value="' . (int)$p['id'] . '"><button class="btn"' . (gateway_active() ? '' : ' disabled') . '>پرداخت</button></form></div>';
        page('خرید اشتراک', $b . '</div>');
    }

    case '/pay/start': {
        $u = need_login();
        if (!$isPost) { redir('/buy'); }
        $plan = row('SELECT * FROM plans WHERE id=? AND is_active=1', [(int)($_POST['plan_id'] ?? 0)]);
        if (!$plan) { $_SESSION['flash'] = flash('err', 'پلن نامعتبر است.'); redir('/buy'); }
        // جلوگیری از ایجاد پرداخت‌های متعدد پشت‌سرهم
        if (!quota_take('paystart:' . $u['id'], 10, 3600)) { $_SESSION['flash'] = flash('err', 'تعداد درخواست پرداخت زیاد است. بعداً تلاش کنید.'); redir('/buy'); }
        $r = pay_start((int)$u['id'], $plan);
        if (!$r['ok']) { $_SESSION['flash'] = flash('err', $r['error']); redir('/buy'); }
        header('Location: ' . $r['url']); exit;
    }

    case '/pay/callback': {
        $r = pay_callback((string)($_GET['gw'] ?? ''), $_GET);
        $b = '<div class="card narrow"><h1>' . ($r['ok'] ? 'پرداخت موفق' : 'پرداخت ناموفق') . '</h1>' . flash($r['ok'] ? 'ok' : 'err', $r['message']);
        if (!empty($r['payment'])) {
            $p = $r['payment'];
            $b .= '<p class="muted">شناسه پیگیری: <b dir="ltr">' . e($p['tracking_code']) . '</b>' . (!empty($p['ref_id']) ? '<br>کد مرجع درگاه: <b dir="ltr">' . e($p['ref_id']) . '</b>' : '') . '</p>';
        }
        page('نتیجه پرداخت', $b . '<a class="btn" href="/panel">بازگشت به پنل</a></div>');
    }

    case '/panel/payments': {
        $u = need_login();
        $list = rows('SELECT p.*, pl.title FROM payments p JOIN plans pl ON pl.id=p.plan_id WHERE p.user_id=? ORDER BY p.id DESC LIMIT 100', [$u['id']]);
        $st = ['paid' => 'موفق', 'pending' => 'در انتظار', 'failed' => 'ناموفق']; $gwl = ['zarinpal' => 'زرین‌پال', 'zibal' => 'زیبال'];
        $b = '<h1>تاریخچه پرداخت‌ها</h1><div class="tablewrap"><table><tr><th>تاریخ</th><th>پلن</th><th>مبلغ</th><th>درگاه</th><th>وضعیت</th><th>شناسه پیگیری</th></tr>';
        foreach ($list as $p) $b .= '<tr><td>' . jdate($p['created_at']) . '</td><td>' . e($p['title']) . '</td><td>' . money((int)$p['amount']) . '</td><td>' . ($gwl[$p['gateway']] ?? '') . '</td><td>' . $st[$p['status']] . '</td><td dir="ltr">' . e($p['tracking_code']) . '</td></tr>';
        if (!$list) $b .= '<tr><td colspan="6" class="muted">پرداختی ثبت نشده است.</td></tr>';
        page('پرداخت‌ها', $b . '</table></div>');
    }

    default:
        http_response_code(404);
        page('یافت نشد', '<div class="card narrow"><h1>۴۰۴</h1><p>صفحه مورد نظر پیدا نشد.</p><a class="btn" href="/">صفحه اصلی</a></div>');
}
