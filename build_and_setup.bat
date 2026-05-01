@echo off
setlocal EnableDelayedExpansion
title Family Economy - Universal Build Tool

:: Ρυθμίσεις Διαδρομών
set "INNO_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
set "ISS_PATH=C:\Users\Vaggelis\Flutter Projects\family_economy\fam_eco_new.iss"
set "NEW_APK_NAME=FamilyBudget_v1.0.apk"

:: Χαρακτήρας Carriage Return για τον spinner
for /f %%a in ('copy /Z "%~dpf0" nul') do set "CR=%%a"

echo ========================================================
echo   STEP 1: Cleaning and Getting Dependencies...
echo ========================================================
call flutter clean >nul 2>&1
call flutter pub get >nul 2>&1
echo [DONE] Project is ready.

echo.
echo ========================================================
echo   STEP 2: Building Android APK (Release)...
echo ========================================================
echo (This may take a moment...)

if exist apk_build_log.txt del apk_build_log.txt
start /b "" flutter build apk --release > apk_build_log.txt 2>&1

:apk_spinner
set /a "idx_a=(idx_a + 1) %% 4"
if !idx_a!==0 set "spin_a=|"
if !idx_a!==1 set "spin_a=/"
if !idx_a!==2 set "spin_a=-"
if !idx_a!==3 set "spin_a=\"

<nul set /p "=Building APK... !spin_a!!CR!"
timeout /t 1 /nobreak >nul

findstr /C:"Built build\app\outputs\flutter-apk\app-release.apk" apk_build_log.txt >nul
if %errorlevel% neq 0 (
    findstr /C:"Error" apk_build_log.txt >nul
    if !errorlevel!==0 (
        echo.
        echo [ERROR] Android build failed! Check apk_build_log.txt.
        goto step3
    )
    goto apk_spinner
)

echo.
echo [DONE] Android APK created successfully.

:: Μετονομασία του αρχείου
move "build\app\outputs\flutter-apk\app-release.apk" "build\app\outputs\flutter-apk\%NEW_APK_NAME%" >nul
echo [INFO] APK renamed to: %NEW_APK_NAME%

echo.
echo ========================================================
echo   STEP 3: Building Windows Release...
echo ========================================================
if exist build_log.txt del build_log.txt
start /b "" flutter build windows --release > build_log.txt 2>&1

:spinner
set /a "idx=(idx + 1) %% 4"
if !idx!==0 set "spin=|"
if !idx!==1 set "spin=/"
if !idx!==2 set "spin=-"
if !idx!==3 set "spin=\"
<nul set /p "=Building Windows... !spin!!CR!"
timeout /t 1 /nobreak >nul
findstr /C:"Built build\windows" build_log.txt >nul
if %errorlevel% neq 0 (
    findstr /C:"Error" build_log.txt >nul
    if !errorlevel!==0 (
        echo.
        echo [ERROR] Windows build failed.
        goto step4
    )
    goto spinner
)
echo.
echo [DONE] Windows Release Built.

:step4
echo.
echo ========================================================
echo   STEP 4: Generating Windows Installer...
echo ========================================================
if exist "%INNO_PATH%" (
    "%INNO_PATH%" "%ISS_PATH%" >nul
    echo [DONE] Windows Setup Created.
)

echo.
echo ========================================================
echo   BUILDS COMPLETED!
echo.
echo   - Android APK: build\app\outputs\flutter-apk\%NEW_APK_NAME%
echo   - Windows EXE: C:\Users\Vaggelis\Flutter Projects\family_economy\InstallerOutput
echo ========================================================

:: Μικρή καθυστέρηση για να προλάβουν οι διεργασίες να κλείσουν
timeout /t 2 /nobreak >nul

:: Προσπάθεια διαγραφής με σίγαση σφαλμάτων (2>nul)
if exist build_log.txt (
    del /f /q build_log.txt >nul 2>&1
)
if exist apk_build_log.txt (
    del /f /q apk_build_log.txt >nul 2>&1
)

echo.
echo [INFO] Temporary log files cleared.
echo.
pause