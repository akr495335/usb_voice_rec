@echo off
:: Run as Administrator
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Running with Administrator privileges...
) else (
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

chcp 65001 > nul
cls
echo.
echo ============================================================
echo    WINDOWS DESKTOP VOICE TYPER - ADMIN MODE
echo ============================================================
echo.
echo ✅ Running with Administrator privileges
echo.
echo HOW TO USE:
echo   1. Notepad ya koi bhi app kholen
echo   2. Ctrl+Shift+Space dabayen (Recording shuru hogi)
echo   3. Mobile microphone me bolen
echo   4. Ctrl+Shift+Space dobara dabayen (Recording band hogi)
echo   5. Text automatically type ho jayega!
echo.
echo Language Toggle: Ctrl+Shift+L
echo.
echo ============================================================
echo.
echo Starting application...
echo.

cd /d "%~dp0"
python voice_typer_app.py

pause
