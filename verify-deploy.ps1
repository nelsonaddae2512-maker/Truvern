<# 
  Truvern Production Validation & Deployment Script
  Run with:
    powershell -ExecutionPolicy Bypass -File .\verify-deploy.ps1 -Deploy
#>

param(
  [switch]$Deploy,
  [string]$ProjectPath = "C:\Users\MR.NELSON\Downloads\truvern",
  [string]$HealthUrl = "https://truvern.com/api/health",
  [int]$Retries = 10,
  [int]$DelaySec = 6
)

$ErrorActionPreference = "Stop"

function Step($m){ Write-Host "`n=== $m ===" }
function Ok($m){ Write-Host "[OK]  $m" -ForegroundColor Green }
function Warn($m){ Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Fail($m){ Write-Host "[FAIL] $m" -ForegroundColor Red }

# -------- Working directory --------
Set-Location -Path $ProjectPath
Step ("Working directory: {0}" -f (Get-Location))

if (-not (Test-Path "package.json")) { throw "package.json not found. Run from project root." }

# -------- Prisma: validate/generate --------
if (Test-Path "prisma/schema.prisma") {
  Step "Prisma validate and generate"
  npx prisma validate
  npx prisma generate
  Ok "Prisma client ready"

  # -------- Apply migrations --------
  Step "Apply Prisma migrations"
  $migrationsPath = "prisma/migrations"
  $hasMigrations = (Test-Path $migrationsPath) -and ((Get-ChildItem $migrationsPath | Where-Object { $_.PSIsContainer }).Count -gt 0)
  if ($hasMigrations) {
    npx prisma migrate deploy
  } else {
    npx prisma migrate dev --name init_auto
  }
  Ok "Migrations applied"

  # -------- Seed if configured --------
  Step "Seed database (if configured)"
  $pkg = Get-Content "package.json" -Raw | ConvertFrom-Json
  $hasSeed = $false
  try { if ($pkg.prisma -and $pkg.prisma.seed) { $hasSeed = $true } } catch {}
  if ($hasSeed) { npx prisma db seed; Ok "Seed complete" } else { Warn "No prisma.seed configured; skipping" }
} else {
  Warn "prisma/schema.prisma not found; skipping Prisma steps"
}

# -------- Build Next.js --------
Step "Build Next.js"
$env:NODE_OPTIONS="--max-old-space-size=4096"
npm run build
Ok "Build complete"

# -------- Optional deploy --------
if ($Deploy) {
  Step "Deploying to Vercel (prod)"
  $cmd = Get-Command vercel -ErrorAction SilentlyContinue
  if ($null -eq $cmd) { npx vercel --prod --confirm } else { vercel --prod --confirm }
  Ok "Deploy triggered"
} else {
  Warn "Skipping deploy (use -Deploy to push live)"
}

# -------- Health check --------
function Test-Health([string]$url, [int]$retries, [int]$delay) {
  for ($i=1; $i -le $retries; $i++) {
    try {
      $sw = [System.Diagnostics.Stopwatch]::StartNew()
      $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 20
      $sw.Stop()
      if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 400) {
        Ok ("Health OK [{0}] in {1} ms" -f $r.StatusCode, [math]::Round($sw.Elapsed.TotalMilliseconds))
        return $true
      } else {
        Write-Host ("Attempt {0}/{1}: HTTP {2}" -f $i,$retries,$r.StatusCode)
      }
    } catch {
      Write-Host ("Attempt {0}/{1} failed -> {2}" -f $i,$retries,$_.Exception.Message)
    }
    Start-Sleep -Seconds $delay
  }
  return $false
}

Step "Health check: $HealthUrl"
$ok = Test-Health -url $HealthUrl -retries $Retries -delay $DelaySec
if (-not $ok) { Fail "Health check failed after $Retries attempts"; exit 1 }

Ok "All done - validated, migrated, seeded, built, health verified."

