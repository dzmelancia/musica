@echo off
setlocal EnableDelayedExpansion

echo ============================================
echo  Monochrome Music -- Android APK Builder
echo ============================================
echo.

:: --- Detect Java 17+ (21 preferred) ---
set "JAVA_EXE="
for /d %%d in (
    "C:\Program Files\Microsoft\jdk-21*"
    "C:\Program Files\Microsoft\jdk-17*"
    "C:\Program Files\Eclipse Adoptium\jdk-21*"
    "C:\Program Files\Eclipse Adoptium\jdk-17*"
    "C:\Program Files\Java\jdk-21*"
    "C:\Program Files\Java\jdk-17*"
) do (
    if exist "%%~d\bin\java.exe" (
        set "JAVA_HOME=%%~d"
        set "JAVA_EXE=%%~d\bin\java.exe"
        goto :java_found
    )
)
:java_found
if defined JAVA_EXE (
    set "PATH=%JAVA_HOME%\bin;%PATH%"
    echo [OK] Java found: %JAVA_HOME%
) else (
    echo [ERROR] Java 17+ not found. Install it via:
    echo         winget install Microsoft.OpenJDK.21
    pause & exit /b 1
)

:: --- Detect Node.js (installed or portable) ---
set "NODE_DIR="

:: Check standard install locations
where node >nul 2>&1
if %errorlevel% equ 0 goto :node_found

:: Check portable location next to this script
if exist "%~dp0node-portable\node.exe" (
    set "NODE_DIR=%~dp0node-portable"
    set "PATH=%NODE_DIR%;%PATH%"
    goto :node_found
)

:: Check Downloads folder
if exist "%USERPROFILE%\Downloads\node-portable\node.exe" (
    set "NODE_DIR=%USERPROFILE%\Downloads\node-portable"
    set "PATH=%NODE_DIR%;%PATH%"
    goto :node_found
)

echo [ERROR] Node.js not found. Install it with:
echo         winget install OpenJS.NodeJS.20
echo.
echo   OR download the portable ZIP from https://nodejs.org/dist/v20.20.2/node-v20.20.2-win-x64.zip
echo   Extract it, rename the folder to "node-portable" and place it next to this script.
pause & exit /b 1

:node_found
for /f "tokens=*" %%v in ('node --version 2^>^&1') do set NODE_VER=%%v
echo [OK] Node.js %NODE_VER% found.

:: --- Detect Android SDK ---
if not defined ANDROID_HOME (
    if exist "%LOCALAPPDATA%\Android\Sdk" set "ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk"
    if exist "%USERPROFILE%\AppData\Local\Android\Sdk" set "ANDROID_HOME=%USERPROFILE%\AppData\Local\Android\Sdk"
)
if defined ANDROID_HOME (
    echo [OK] Android SDK: %ANDROID_HOME%
    set "PATH=%ANDROID_HOME%\platform-tools;%ANDROID_HOME%\tools\bin;%PATH%"
) else (
    echo [WARN] ANDROID_HOME not set. Install Android Studio to get the SDK.
    echo        Build may fail. If it does, install Android Studio and retry.
)
echo.

:: --- 1. Install dependencies ---
echo [1/5] Installing npm dependencies...
call npm install
if %errorlevel% neq 0 ( echo [ERROR] npm install failed. & pause & exit /b 1 )
echo.

:: --- 2. Build web app ---
echo [2/5] Building web app (Vite)...
call npm run build
if %errorlevel% neq 0 ( echo [ERROR] Vite build failed. & pause & exit /b 1 )
echo.

:: --- 3. Capacitor sync ---
echo [3/5] Syncing Capacitor Android...
call npx cap sync android
if %errorlevel% neq 0 ( echo [ERROR] Capacitor sync failed. & pause & exit /b 1 )
echo.

:: --- 4. Gradle build ---
echo [4/5] Building debug APK with Gradle...
cd android
call gradlew.bat assembleDebug --no-daemon
if %errorlevel% neq 0 (
    echo [ERROR] Gradle build failed. Common fixes:
    echo   - Set ANDROID_HOME to your Android SDK path
    echo   - Run: sdkmanager "platforms;android-36" "build-tools;35.0.0"
    cd .. & pause & exit /b 1
)
cd ..
echo.

:: --- 5. Report ---
echo [5/5] Build complete!
echo.
set "APK=android\app\build\outputs\apk\debug\app-debug.apk"
if exist "%APK%" (
    echo APK: %CD%\%APK%
    echo.
    echo Install on a connected Android device:
    echo   adb install %APK%
    echo.
    echo Or copy the APK to your phone and install manually.
) else (
    echo [WARN] APK not found at: %APK%
)
pause
