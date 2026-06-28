@echo off
title VolumeGuardian Unlock
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\VolumeUnlock.ps1"
pause
