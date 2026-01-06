param([switch]$DeployVercel)

$ErrorActionPreference = "Stop"

function Exec([string]$cmd, [string]$args = "") {
  Write-Host "`n> Running:" $cmd $args -ForegroundColor Cyan
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $cmd
  $psi.Arguments = $args
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow  = $true
  $p = [System.Diagnostics.Process]::Start($psi)
  $out = $p.StandardOutput.ReadToEnd()
  $err = $p.StandardError.ReadToEnd()
  $p.WaitForExit()
  if ($p.ExitCode -ne 0) {
    if ($err) { Write-Host $err -ForegroundColor Red }
    throw "Command failed (exit $($p.ExitCode)): $cmd $args"
  }
  if ($out) { Write-Host $out }
}

# ---- script starts here ----
Set-Location $PSScriptRoot

Write-Host "`nPulling production env into .env.local..." -ForegroundColor Yellow
Exec "npx" 'vercel env pull ".env.local" --environment=production --yes'

Write-Host "`nPrisma generate..." -ForegroundColor Yellow
Exec "npx" "prisma generate"

Write-Host "`nPrisma migrate deploy..." -ForegroundColor Yellow
Exec "npx" "prisma migrate deploy"

if ($DeployVercel) {
  Write-Host "`nDeploying to Vercel (production)..." -ForegroundColor Yellow
  $vercel = (Get-Command vercel -ErrorAction SilentlyContinue).Source
  $token  = $env:VERCEL_TOKEN
  $tokArg = if ($token) { " --token $token" } else { "" }
  if ($vercel) { Exec $vercel ("--prod$tokArg") } else { Exec "npx" ("vercel --prod$tokArg") }
}

Write-Host "`nAll done." -ForegroundColor Green
[void](Read-Host "`nPress Enter to close")
