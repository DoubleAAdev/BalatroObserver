@echo off
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0start-viewer.ps1"
if errorlevel 1 pause
