$ErrorActionPreference = "Stop"

Write-Host "`n== Truvern production deploy lock ==" -ForegroundColor Cyan

if ((Get-Location).Path -ieq "C:\WINDOWS\system32") {
  throw "Refusing to run from C:\WINDOWS\system32. cd into C:\dev\truvern first."
}

if (-not (Test-Path ".\package.json")) {
  throw "package.json not found. Run this from C:\dev\truvern."
}

Write-Host "`nChecking Vercel project link..." -ForegroundColor Yellow
if (-not (Test-Path ".\.vercel\project.json")) {
  vercel link
}

$link = Get-Content ".\.vercel\project.json" -Raw | ConvertFrom-Json
Write-Host "Linked Vercel project: $($link.projectId)" -ForegroundColor Gray

Write-Host "`nRunning typecheck..." -ForegroundColor Yellow
npx tsc --noEmit

Write-Host "`nRunning production build..." -ForegroundColor Yellow
npm run build

Write-Host "`nDeploying to Vercel Production..." -ForegroundColor Yellow
vercel deploy --prod

Write-Host "`nDone. Production deploy command completed." -ForegroundColor Green
