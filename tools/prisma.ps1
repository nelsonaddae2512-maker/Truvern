# tools\prisma.ps1
# Run Prisma commands safely from the repo root (never from system32).
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\tools\prisma.ps1 -Cmd migrate:dev -Name "artifact_ledger"
#   powershell -ExecutionPolicy Bypass -File .\tools\prisma.ps1 -Cmd generate
#   powershell -ExecutionPolicy Bypass -File .\tools\prisma.ps1 -Cmd db:push
#   powershell -ExecutionPolicy Bypass -File .\tools\prisma.ps1 -Cmd studio

param(
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$Cmd,

  [string]$Name = "",
  [string]$Schema = ".\prisma\schema.prisma",
  [string[]]$Args = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

# Ensure we're in repo root
$repoRoot = (Resolve-Path ".").Path
if (-not (Test-Path (Join-Path $repoRoot "package.json"))) {
  Fail "Run this from your repo root (where package.json is). Current: $repoRoot"
}

# Resolve schema path
try { $schemaFull = (Resolve-Path $Schema).Path } catch { Fail "Schema not found: $Schema" }

# Prefer pnpm if available, otherwise fallback to npx
$pnpm = Get-Command pnpm -ErrorAction SilentlyContinue
$npx  = Get-Command npx  -ErrorAction SilentlyContinue
if (-not $pnpm -and -not $npx) { Fail "Neither pnpm nor npx is available on PATH." }

# Map friendly commands -> prisma args
$prismaArgs = @()
switch ($Cmd.ToLowerInvariant()) {
  "generate"       { $prismaArgs = @("generate") }
  "format"         { $prismaArgs = @("format") }
  "validate"       { $prismaArgs = @("validate") }
  "studio"         { $prismaArgs = @("studio") }
  "db:push"        { $prismaArgs = @("db","push") }
  "db:pull"        { $prismaArgs = @("db","pull") }
  "migrate:dev"    {
    $prismaArgs = @("migrate","dev")
    if ($Name) { $prismaArgs += @("--name", $Name) }
  }
  "migrate:deploy" { $prismaArgs = @("migrate","deploy") }
  "migrate:status" { $prismaArgs = @("migrate","status") }
  "migrate:reset"  { $prismaArgs = @("migrate","reset") }
  default {
    Fail "Unknown -Cmd '$Cmd'. Allowed: generate, format, validate, studio, db:push, db:pull, migrate:dev, migrate:deploy, migrate:status, migrate:reset"
  }
}

# Always pass schema explicitly
$finalArgs = $prismaArgs + @("--schema", $schemaFull) + $Args

Write-Host ""
Write-Host "Repo:   $repoRoot"
Write-Host "Schema: $schemaFull"
Write-Host "Cmd:    $Cmd"
Write-Host "Runner: " -NoNewline
if ($pnpm) { Write-Host "pnpm" } else { Write-Host "npx" }
Write-Host "Args:   prisma $($finalArgs -join ' ')"
Write-Host ""

Push-Location $repoRoot
try {
  if ($pnpm) {
    # ✅ use modern Prisma CLI package name
    & pnpm exec prisma @finalArgs
  } else {
    & npx prisma @finalArgs
  }

  if ($LASTEXITCODE -ne 0) {
    Fail "Prisma command failed (exit code $LASTEXITCODE)."
  }
}
finally {
  Pop-Location
}