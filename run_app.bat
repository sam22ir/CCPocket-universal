@echo off
REM ============================================================
REM run_app.bat — تشغيل CCPocket Universal
REM يضع Chrome cache على D: لتجنب مشاكل C: الممتلئة
REM ============================================================
REM
REM المتطلبات (مرة واحدة فقط):
REM   1. Node.js >= 22
REM   2. Flutter SDK
REM   3. uv (Python package manager):
REM        pip install uv
REM   4. free-claude-code proxy:
REM        uv tool install git+https://github.com/Alishahryar1/free-claude-code.git
REM
REM ثم في التطبيق: الإعدادات → Proxy → تشغيل
REM ============================================================

SET TEMP=D:\flutter_temp
SET TMP=D:\flutter_temp
SET CHROME_EXTRA_ARGS=--disk-cache-dir=D:\chrome_flutter_profile\cache --disk-cache-size=104857600

cd /d "%~dp0apps\mobile"

echo [1/2] Starting Bridge Server...
start "CCPocket Bridge" cmd /k "cd /d %~dp0packages\bridge && node --experimental-strip-types src/server.ts"

timeout /t 3 /nobreak >nul

echo [2/2] Starting Flutter App on Chrome...
flutter run -d chrome --web-port=9090

pause
