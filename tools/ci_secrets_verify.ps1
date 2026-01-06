# =========================================================
# Truvern CI Secrets & Connectivity Verification (Final Clean Version)
# Works on Windows PowerShell 5.1+
# =========================================================

param([switch]$StayOpen)

$ErrorActionPreference = 'Stop'

function Say([string]$t){ Write-Host $t }
function OK([string]$t){ Write-Host ("OK: " + $t) -ForegroundColor Green }
function Warn([string]$t){ Write-Host ("WARN: " + $t) -ForegroundColor Yellow }
function Fail([string]$t){ Write-Host ("ERROR: " + $t) -ForegroundColor Red }

function Test-Tcp {
    param([string]$TargetHost, [int]$Port, [int]$TimeoutMs = 4000)
    try {
        Write-Host ("- testing TCP " + $TargetHost + ":" + $Port + " ...") -NoNewline
        $client = New-Object System.Net.Sockets.TcpClient
        $iar = $client.BeginConnect($TargetHost, $Port, $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) {
            $client.Close()
            Write-Host ""
            Fail ("timeout after " + $TimeoutMs + " ms")
            return $false
        }
        $client.EndConnect($iar)
        $client.Close()
        Write-Host ""
        OK "connection OK"
        return $true
    } catch {
        Write-Host ""
        Fail $_.Exception.Message
        return $false
    }
}

function Get-DbHostFromUrl {
    param([string]$Url)
    if (-not $Url) { return $null }
    try {
        $u = [Uri]$Url
        return $u.Host
    } catch {
        return $null
    }
}

# ---------- Read environment variables ----------
$VERCEL_TOKEN         = $env:VERCEL_TOKEN
$VERCEL_ORG_ID        = $env:VERCEL_ORG_ID
$VERCEL_PROJECT_ID    = $env:VERCEL_PROJECT_ID
$APP_URL              = $env:APP_URL
$DATABASE_URL_STAGING = $env:DATABASE_URL_STAGING

Say ""
Say "=== Environment check (expected for GitHub Actions) ==="

function Mask($s){
    if ([string]::IsNullOrEmpty($s)) { return "<not set>" }
    if ($s.Length -le 6) { return ("*" * $s.Length) }
    return ($s.Substring(0,3) + ("*" * [Math]::Min(12, $s.Length-6)) + $s.Substring($s.Length-3))
}

# --- Prepare safe values before building hashtable ---
$appValue = if ([string]::IsNullOrWhiteSpace($APP_URL)) { "<not set>" } else { $APP_URL }
$dbValue  = if ([string]::IsNullOrWhiteSpace($DATABASE_URL_STAGING)) { "<not set>" } else { "<set>" }
$orgValue = if ([string]::IsNullOrWhiteSpace($VERCEL_ORG_ID)) { "<not set>" } else { $VERCEL_ORG_ID }
$prjValue = if ([string]::IsNullOrWhiteSpace($VERCEL_PROJECT_ID)) { "<not set>" } else { $VERCEL_PROJECT_ID }

$rows = @(
    @{ Name="VERCEL_TOKEN";         Value=(Mask $VERCEL_TOKEN) }
    @{ Name="VERCEL_ORG_ID";        Value=$orgValue }
    @{ Name="VERCEL_PROJECT_ID";    Value=$prjValue }
    @{ Name="APP_URL";              Value=$appValue }
    @{ Name="DATABASE_URL_STAGING"; Value=$dbValue }
)

Write-Host ("{0,-24} {1}" -f "Name","Value")
Write-Host ("{0,-24} {1}" -f "------------------------","----------------------------------------")
foreach($r in $rows){ Write-Host ("{0,-24} {1}" -f $r.Name, $r.Value) }

# --- Missing variable detection ---
$missing = @()
foreach($k in @("VERCEL_TOKEN","VERCEL_ORG_ID","VERCEL_PROJECT_ID")){
    if (-not (Get-Variable -Name $k -ValueOnly)) { $missing += $k }
}
if ($missing.Count -gt 0) {
    Fail ("Missing required env var(s): " + ($missing -join ", "))
} else {
    OK "All required env vars present."
}

# ---------- Write JSON preview ----------
$toolsDir = Join-Path (Get-Location).Path "tools"
if (-not (Test-Path $toolsDir)) { New-Item -ItemType Directory -Path $toolsDir | Out-Null }
$outJson = Join-Path $toolsDir "ci_secrets_preview.json"

$preview = @{
    VERCEL_ORG_ID     = $VERCEL_ORG_ID
    VERCEL_PROJECT_ID = $VERCEL_PROJECT_ID
    APP_URL           = $APP_URL
    DATABASE_URL      = $DATABASE_URL_STAGING
}
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outJson, (ConvertTo-Json $preview), $utf8NoBom)
Say ""
Say ("Saved: " + $outJson)

# ---------- Connectivity tests ----------
Say ""
Say "=== Connectivity tests (outbound TCP) ==="
$allOk = $true
$allOk = (Test-Tcp -TargetHost "api.vercel.com" -Port 443) -and $allOk
$allOk = (Test-Tcp -TargetHost "vercel.com" -Port 443) -and $allOk
$allOk = (Test-Tcp -TargetHost "github.com" -Port 443) -and $allOk

if ($APP_URL) {
    try {
        $uri = [Uri]$APP_URL
        $host = $uri.Host
        if ($uri.Port -gt 0) { $port = $uri.Port } else { if ($uri.Scheme -eq "https") { $port = 443 } else { $port = 80 } }
        $allOk = (Test-Tcp -TargetHost $host -Port $port) -and $allOk
    } catch {
        Warn ("APP_URL is not a valid URL: " + $APP_URL)
        $allOk = $false
    }
} else {
    Warn "APP_URL not set; skipping app connectivity."
}

$dbHost = Get-DbHostFromUrl -Url $DATABASE_URL_STAGING
if ($dbHost) {
    $allOk = (Test-Tcp -TargetHost $dbHost -Port 5432) -and $allOk
} else {
    Warn "DATABASE_URL_STAGING not set or host not parsed; skipping DB connectivity."
}

# ---------- Summary ----------
Say ""
Say "=== Summary ==="
if ($missing.Count -gt 0) { Fail ("Missing required env vars: " + ($missing -join ", ")) } else { OK "Required env vars are present." }
if ($allOk) { OK "All tested hosts reachable." } else { Warn "One or more hosts were unreachable." }

# ---------- Exit ----------
$code = if ($missing.Count -gt 0 -or -not $allOk) { 1 } else { 0 }

if ($StayOpen) {
    Say ("(Exit code " + $code + ") Press Enter to close...")
    [void][Console]::ReadLine()
}

exit $code
