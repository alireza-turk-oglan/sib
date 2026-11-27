<?php
// روتر سرور داخلی PHP برای اجرای لوکال (معادل .htaccess). فقط برای توسعه.
$root = dirname(__DIR__) . '/public';
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
if ($path !== '/' && is_file($root . $path) && !preg_match('/\.php$/', $path)) return false;
chdir($root);
if (preg_match('#^/api/v1/(.+)$#', $path, $m)) { $_GET['r'] = $m[1]; $file = 'api.php'; }
elseif (preg_match('#^/admin(/.*)?$#', $path)) $file = 'admin.php';
elseif ($path === '/install.php') $file = 'install.php';
else $file = 'index.php';
$_SERVER['SCRIPT_NAME'] = '/' . $file; $_SERVER['SCRIPT_FILENAME'] = "$root/$file";
require "$root/$file";
