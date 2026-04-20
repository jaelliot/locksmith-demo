@echo off
setlocal
set "SCRIPT_DIR=%~dp0"

rem cmd.exe prints its UNC warning before this script starts. pushd maps the repo root to a drive
rem for the rest of this run so PowerShell inherits a stable working directory afterward.
pushd "%SCRIPT_DIR%.." >nul 2>nul
if errorlevel 1 (
	powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%demo-day.ps1" %*
	exit /b %ERRORLEVEL%
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\demo-day.ps1" %*
set "EXIT_CODE=%ERRORLEVEL%"
popd
exit /b %EXIT_CODE%
