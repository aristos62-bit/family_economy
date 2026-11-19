@echo off
setlocal EnableDelayedExpansion
title Family Economy - Final Build Tool

:: ==========================================================
:: Family Economy - Final Build Tool
:: ----------------------------------------------------------
:: Merges build_and_setup.bat + build_and_setup_new.bat
::   - reads version from pubspec.yaml (source of truth)
::   - names the APK with the real version
::   - names the installer with the real version (FamilyBudgetSetup_vX.Y.Z.exe)
::   - passes AppVersion + build number to Inno Setup (2.0.1+2 -> 2.0.1.2)
::   - verifies the produced setup.exe really carries that version
::   - detects build failures (no infinite spinner)
::   - writes a log per step in build_logs\
::   - cleans build\ + windows\flutter\ephemeral
::   - verifies the bundled Firebase C++ SDK version
:: Usage:
::   build_and_setup_final.bat          full (clean + apk + win + setup)
::   build_and_setup_final.bat fast     skip clean
::   set NO_PAUSE=1                     no pause at the end
:: ==========================================================

:: ---------------- Settings ----------------
set "PROJECT_DIR=%~dp0"
cd /d "%PROJECT_DIR%"

set "INNO_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
set "ISS_PATH=%PROJECT_DIR%fam_eco_new.iss"
set "LOG_DIR=%PROJECT_DIR%build_logs"

set "APK_DIR=build\app\outputs\flutter-apk"
set "WIN_DIR=build\windows\x64\runner\Release"
set "INST_DIR=InstallerOutput"
:: INST_NAME ορίζεται μετά την ανάγνωση της έκδοσης (STEP 0) - περιέχει την έκδοση

set "DO_CLEAN=1"
if /i "%~1"=="fast" set "DO_CLEAN=0"

for /f %%a in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMddHHmmss"') do set "STAMP=%%a"
if not defined STAMP set "STAMP=build"

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>&1
set "PUB_LOG=%LOG_DIR%\pubget_!STAMP!.log"
set "APK_LOG=%LOG_DIR%\apk_!STAMP!.log"
set "WIN_LOG=%LOG_DIR%\windows_!STAMP!.log"
set "INNO_LOG=%LOG_DIR%\inno_!STAMP!.log"

:: ---------------- STEP 0: version from pubspec ----------------
set "FULL_VER="
for /f "tokens=2 delims=: " %%v in ('findstr /b /c:"version:" "pubspec.yaml"') do if not defined FULL_VER set "FULL_VER=%%v"

if not defined FULL_VER (
    echo [ERROR] Could not read "version:" from pubspec.yaml
    goto failed
)

for /f "tokens=1,2 delims=+" %%a in ("!FULL_VER!") do (
    set "APP_VER=%%a"
    set "BUILD_NO=%%b"
)
if not defined APP_VER goto ver_fail
if not defined BUILD_NO set "BUILD_NO=0"
set "APK_NAME=FamilyBudget_v!APP_VER!.apk"

:: Installer: όνομα με έκδοση + αναμενόμενη έκδοση αρχείου (4 μέρη)
set "INST_BASE=FamilyBudgetSetup_v!APP_VER!"
set "INST_NAME=!INST_BASE!.exe"
set "SETUP_VER=!APP_VER!.!BUILD_NO!"

echo ========================================================
echo   FAMILY ECONOMY - FINAL BUILD
echo   Version : !APP_VER!+!BUILD_NO!
echo   APK     : !APK_NAME!
echo   Setup   : %INST_DIR%\!INST_NAME!
echo   Mode    : !DO_CLEAN!  ^(1 = full clean, 0 = fast^)
echo ========================================================

:: ---------------- STEP 1: clean + dependencies ----------------
echo.
echo --------------------------------------------------------
echo  STEP 1/5  Clean and dependencies
echo --------------------------------------------------------

if "!DO_CLEAN!"=="1" (
    echo  [INFO] Removing build folder and windows ephemeral...
    if exist "build" rmdir /s /q "build" >nul 2>&1
    if exist "windows\flutter\ephemeral" rmdir /s /q "windows\flutter\ephemeral" >nul 2>&1

    if exist "build" (
        echo  [INFO] Build folder locked - stopping Gradle / Dart / ADB...
        call :kill_locks
        rmdir /s /q "build" >nul 2>&1
    )

    call flutter clean >nul 2>&1

    if exist "build" (
        echo  [WARN] build folder could not be fully removed
    ) else (
        echo  [OK] Clean complete
    )
) else (
    echo  [INFO] Fast mode - clean skipped
)

call flutter pub get > "!PUB_LOG!" 2>&1
if errorlevel 1 (
    echo  [ERROR] flutter pub get failed - see !PUB_LOG!
    goto failed
)
echo  [OK] Dependencies ready

:: ---------------- STEP 2: Android APK ----------------
echo.
echo --------------------------------------------------------
echo  STEP 2/5  Android APK ^(release^)
echo --------------------------------------------------------
echo  [INFO] Log: !APK_LOG!

powershell -NoProfile -Command "flutter build apk --release 2>&1 | Tee-Object -FilePath '!APK_LOG!'; exit $LASTEXITCODE"
if errorlevel 1 goto apk_failed

if not exist "%APK_DIR%\app-release.apk" (
    echo  [ERROR] app-release.apk not found after build
    goto failed
)

move /y "%APK_DIR%\app-release.apk" "%APK_DIR%\!APK_NAME!" >nul
echo  [OK] APK: %APK_DIR%\!APK_NAME!

:: ---------------- STEP 3: Windows release ----------------
echo.
echo --------------------------------------------------------
echo  STEP 3/5  Windows release
echo --------------------------------------------------------
echo  [INFO] Log: !WIN_LOG!

powershell -NoProfile -Command "flutter build windows --release 2>&1 | Tee-Object -FilePath '!WIN_LOG!'; exit $LASTEXITCODE"
if errorlevel 1 goto win_failed

if not exist "%WIN_DIR%\family_economy.exe" (
    echo  [ERROR] family_economy.exe not found after build
    goto failed
)
echo  [OK] EXE: %WIN_DIR%\family_economy.exe

:: ---------------- STEP 4: bundled Firebase C++ SDK check ----------------
echo.
echo --------------------------------------------------------
echo  STEP 4/5  Verify bundled Firebase C++ SDK
echo --------------------------------------------------------
set "FB_VER=unknown"
set "FB_VH=build\windows\x64\extracted\firebase_cpp_sdk_windows\include\firebase\version.h"

if exist "!FB_VH!" (
    set "FB_M="
    set "FB_m="
    set "FB_r="
    for /f "tokens=3" %%a in ('findstr /c:"#define FIREBASE_VERSION_MAJOR" "!FB_VH!"') do set "FB_M=%%a"
    for /f "tokens=3" %%a in ('findstr /c:"#define FIREBASE_VERSION_MINOR" "!FB_VH!"') do set "FB_m=%%a"
    for /f "tokens=3" %%a in ('findstr /c:"#define FIREBASE_VERSION_REVISION" "!FB_VH!"') do set "FB_r=%%a"
    set "FB_VER=!FB_M!.!FB_m!.!FB_r!"
    echo  [OK] Firebase C++ SDK: !FB_VER!
) else (
    echo  [WARN] version.h not found - could not verify Firebase C++ SDK
)

:: ---------------- STEP 5: Windows installer ----------------
echo.
echo --------------------------------------------------------
echo  STEP 5/5  Windows installer ^(Inno Setup^)
echo --------------------------------------------------------

if not exist "!INNO_PATH!" (
    echo  [WARN] Inno Setup not found: !INNO_PATH!
    goto summary
)
if not exist "!ISS_PATH!" (
    echo  [ERROR] Missing installer script: !ISS_PATH!
    goto failed
)

"%INNO_PATH%" /DMyAppVersion=!APP_VER! /DMyBuildNo=!BUILD_NO! /DMyOutputBase=!INST_BASE! "!ISS_PATH!" > "!INNO_LOG!" 2>&1
if errorlevel 1 (
    echo  [ERROR] Inno Setup failed - see !INNO_LOG!
    goto failed
)
if not exist "%INST_DIR%\%INST_NAME%" (
    echo  [ERROR] %INST_DIR%\%INST_NAME% was not created
    goto failed
)
echo  [OK] Setup: %INST_DIR%\%INST_NAME%

:: Έλεγχος ότι το setup.exe φέρει την έκδοση που ζητήθηκε (αποτρέπει stale/λάθος build)
:: ΣΗΜΕΙΩΣΗ: το ProductVersion επιστρέφεται με κενά στο τέλος -> πάντα .Trim()
powershell -NoProfile -Command "$i='%INST_DIR%\%INST_NAME%'; $want='!SETUP_VER!'.Trim(); $got=((Get-Item $i).VersionInfo.ProductVersion).Trim(); if ($got -ne $want) { Write-Host ('[ERROR] Setup ProductVersion is [' + $got + '] but expected [' + $want + ']'); exit 1 }"
if errorlevel 1 (
    echo  [ERROR] Installer version mismatch - see !INNO_LOG!
    goto failed
)

:: ---------------- Summary ----------------
:summary
echo.
echo ========================================================
echo   BUILD SUMMARY
echo ========================================================
echo   App version  : !APP_VER!+!BUILD_NO!
echo   Firebase C++ : !FB_VER!
echo   APK          : %APK_DIR%\!APK_NAME!
echo   Windows EXE  : %WIN_DIR%\family_economy.exe
echo   Installer    : %INST_DIR%\%INST_NAME%
echo   Setup ver.   : !SETUP_VER!
echo   Logs         : %LOG_DIR%
echo ========================================================

powershell -NoProfile -Command "$a='%APK_DIR%\!APK_NAME!'; if (Test-Path $a) { 'APK size     : ' + [math]::Round((Get-Item $a).Length/1MB,1) + ' MB' }"
powershell -NoProfile -Command "$e='%WIN_DIR%\family_economy.exe'; if (Test-Path $e) { 'EXE version  : ' + (Get-Item $e).VersionInfo.ProductVersion }"
powershell -NoProfile -Command "$i='%INST_DIR%\%INST_NAME%'; if (Test-Path $i) { 'Setup version: ' + ((Get-Item $i).VersionInfo.ProductVersion).Trim() + '  (' + [math]::Round((Get-Item $i).Length/1MB,1) + ' MB)' }"

echo.
echo [DONE] Build finished successfully.
if not defined NO_PAUSE pause
exit /b 0

:: ---------------- Failure paths ----------------
:apk_failed
echo  [ERROR] Android build FAILED - see !APK_LOG!
goto failed

:win_failed
echo  [ERROR] Windows build FAILED - see !WIN_LOG!
goto failed

:ver_fail
echo  [ERROR] Could not parse version from pubspec.yaml ^(expected: version: X.Y.Z+N^)
goto failed

:failed
echo.
echo ========================================================
echo   BUILD ABORTED - see logs in %LOG_DIR%
echo ========================================================
if not defined NO_PAUSE pause
exit /b 1

:: ---------------- Subroutines ----------------
:kill_locks
taskkill /F /IM java.exe >nul 2>&1
taskkill /F /IM dart.exe >nul 2>&1
taskkill /F /IM adb.exe >nul 2>&1
timeout /t 1 >nul
exit /b
