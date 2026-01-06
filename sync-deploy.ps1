# --- sync-deploy.ps1 ---
$ErrorActionPreference = "Stop"

Write-Host "`n▶ Running Prisma..." -ForegroundColor Cyan
npx prisma generate
npx prisma db push
npx prisma db seed

Write-Host "`n▶ Deploying with Vercel..." -ForegroundColor Cyan
npx vercel --prod

Write-Host "`n🎉 Done! Build triggered on Vercel." -ForegroundColor Green
Write-Host "Next:"
Write-Host "  - Visit Prisma Studio: npm exec prisma studio"
Write-Host "  - Check deployment logs: https://vercel.com/dashboard"
