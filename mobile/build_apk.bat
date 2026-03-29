@echo off
echo ================================
echo   Building TRAWiMe APK
echo ================================
echo.

echo [1/3] Cleaning previous builds...
flutter clean

echo [2/3] Getting dependencies...
flutter pub get

echo [3/3] Building release APK...
flutter build apk --release

echo.
echo ================================
echo   Build Complete!
echo ================================
echo.
echo APK Location:
echo build\app\outputs\flutter-apk\app-release.apk
echo.
echo File size:
dir build\app\outputs\flutter-apk\app-release.apk | find "app-release.apk"
echo.
pause
