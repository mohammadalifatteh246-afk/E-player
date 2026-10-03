Write-Host "Building E-Player Releases..." -ForegroundColor Cyan

# Ensure Windows platform is added
flutter create --platforms windows .

# Build Android APK (using debug signing for local test, swap to release in CI)
Write-Host "Building Android APK..." -ForegroundColor Yellow
flutter build apk --release

# Build Windows EXE
Write-Host "Building Windows EXE..." -ForegroundColor Yellow
flutter build windows --release

Write-Host "Build Complete!" -ForegroundColor Green
Write-Host "Your Android APK is located at: $(pwd)\build\app\outputs\flutter-apk\app-release.apk"
Write-Host "Your Windows EXE is located at: $(pwd)\build\windows\runner\Release\app.exe"
