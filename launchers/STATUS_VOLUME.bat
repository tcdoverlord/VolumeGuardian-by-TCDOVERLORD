@echo off
title VolumeGuardian Status
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\VolumeStatus.ps1"
pause
