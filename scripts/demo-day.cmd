@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0demo-day.ps1" %*
exit /b %ERRORLEVEL%
