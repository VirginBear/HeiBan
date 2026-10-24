@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Collect-InputLatency.ps1" -Executable "%~dp0HeiBan.exe" -RenderPath xaml -WetBatch 16
pause
