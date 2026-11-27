@echo off
chcp 65001 >nul
set PHP=php
where php >nul 2>nul || set PHP=C:\xampp\php\php.exe
echo آدرس سایت:  http://localhost:8000
echo نصب:        http://localhost:8000/install.php
echo پنل مدیر:   http://localhost:8000/admin
echo برای توقف: Ctrl+C
"%PHP%" -S localhost:8000 -t public tools\router.php
