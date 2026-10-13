# Script to build and deploy Flutter Web to GitHub Pages
$ErrorActionPreference = "Stop"

$RootGitDir = (Get-Item $PSScriptRoot).Parent.FullName
$CommitHash = & git -C $RootGitDir rev-parse --short HEAD

Write-Host "--> Building Flutter Web for GitHub Pages (Commit: $CommitHash)..." -ForegroundColor Cyan
$AppDir = Resolve-Path "$PSScriptRoot/../app"
Set-Location -Path $AppDir
& flutter build web --base-href "/low-code/" --dart-define-from-file=.env.flutter

if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed!" -ForegroundColor Red
    exit 1
}

Write-Host "--> Deploying static files to gh-pages branch on GitHub..." -ForegroundColor Cyan
$WebDir = Resolve-Path "$PSScriptRoot/../app/build/web"
Set-Location -Path $WebDir

if (Test-Path ".git") {
    Remove-Item -Recurse -Force ".git"
}

git init
git checkout -B gh-pages
git add -A
git commit -m "Deploy Flutter Web to GitHub Pages ($CommitHash)"
git remote add origin https://github.com/3towson/low-code.git
git push -f origin gh-pages
Remove-Item -Recurse -Force ".git"

Set-Location -Path $RootGitDir
Write-Host "==> Success! Your web app is live at: https://3towson.github.io/low-code/" -ForegroundColor Green

