# สคริปต์ Build และ Deploy Flutter Web ขึ้น GitHub Pages (เปิดได้ 24 ชม.)
$ErrorActionPreference = "Stop"

Write-Host "--> กำลัง Build Flutter Web สำหรับ GitHub Pages..." -ForegroundColor Cyan
Set-Location -Path "$PSScriptRoot/../app"
& C:\flutter\bin\flutter.bat build web --base-href "/low-code/" --dart-define-from-file=.env.flutter

if ($LASTEXITCODE -ne 0) {
    Write-Host "Build ล้มเหลว!" -ForegroundColor Red
    exit 1
}

Write-Host "--> กำลังส่งไฟล์ขึ้น branch gh-pages บน GitHub..." -ForegroundColor Cyan
Set-Location -Path "$PSScriptRoot/../app/build/web"
git init
git checkout -B gh-pages
git add -A
git commit -m "Deploy Flutter Web to GitHub Pages"
git remote add origin https://github.com/3towson/low-code.git
git push -f origin gh-pages
Remove-Item -Recurse -Force ".git"

Write-Host "==> เรียบร้อย! เว็บไซต์ของคุณจะอัปเดตที่: https://3towson.github.io/low-code/" -ForegroundColor Green
