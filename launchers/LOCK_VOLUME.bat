@echo off
title VolumeGuardian Lock
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\VolumeLock.ps1"
pause
