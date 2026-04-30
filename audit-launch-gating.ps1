$ErrorActionPreference = "Stop"

Write-Host "`n=== Truvern Launch Gating Audit ===`n"

$patterns = @(
  "FREE",
  "PRO",
  "ENTERPRISE",
  "plan",
  "orgPlan",
  "subscription",
  "isPro",
  "isEnterprise",
  "templateTier",
  "truvern_starter_baseline",
  "catalog/install",
  "upgrade",
  "checkout",
  "canInstall",
  "requireDbOrganization"
)

Get-ChildItem -Path .\app,.\lib,.\components,.\prisma -Recurse -Include *.ts,*.tsx,*.prisma |
  Select-String -Pattern $patterns |
  Select Path,LineNumber,Line |
  Sort-Object Path,LineNumber |
  Format-Table -AutoSize

Write-Host "`n=== Critical route files ===`n"

$files = @(
  "app/api/assessment-templates/catalog/install/route.ts",
  "app/api/assessment-templates/catalog/upgrade/route.ts",
  "app/(app)/assessment-templates/catalog/page.tsx",
  "app/(app)/assessments/new/page.tsx",
  "app/(app)/vendors/[id]/page.tsx",
  "app/api/vendors/[id]/assessments/apply/route.ts",
  "app/api/vendors/[id]/assessments/apply-starter/route.ts",
  "app/api/billing/checkout/route.ts",
  "app/api/billing/summary/route.ts",
  "lib/org-db.ts"
)

foreach ($f in $files) {
  if (Test-Path $f) {
    Write-Host "FOUND   $f" -ForegroundColor Green
  } else {
    Write-Host "MISSING $f" -ForegroundColor Red
  }
}

Write-Host "`n=== Type/build check ===`n"
npx tsc --noEmit
npm run build