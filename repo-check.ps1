$ErrorActionPreference = "SilentlyContinue"

$root = Get-Location
$outDir = Join-Path $root "repo-check"

if (!(Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

function Write-File {
    param(
        [string]$Path,
        [string[]]$Lines
    )
    $Lines | Out-File -FilePath $Path -Encoding utf8
}

# 1) Full repo tree
cmd /c tree /F /A > (Join-Path $outDir "01-tree.txt")

# 2) App router structure
$appLines = @()
$appLines += "APP ROUTES"
$appLines += "=========="
Get-ChildItem ".\app" -Recurse -File |
    Where-Object { $_.Name -match '^(page|layout|route)\.(ts|tsx|js|jsx)$' } |
    ForEach-Object { $appLines += $_.FullName }

Write-File -Path (Join-Path $outDir "02-app-routes.txt") -Lines $appLines

# 3) API routes
$apiLines = @()
$apiLines += "API ROUTES"
$apiLines += "=========="
Get-ChildItem "." -Recurse -File |
    Where-Object { $_.FullName -match '\\api\\.*\\route\.(ts|tsx|js|jsx)$' } |
    ForEach-Object { $apiLines += $_.FullName }

Write-File -Path (Join-Path $outDir "03-api-routes.txt") -Lines $apiLines

# 4) Package.json
if (Test-Path ".\package.json") {
    Get-Content ".\package.json" | Out-File -FilePath (Join-Path $outDir "04-package-json.txt") -Encoding utf8
}

# 5) Prisma schema
if (Test-Path ".\prisma\schema.prisma") {
    Get-Content ".\prisma\schema.prisma" | Out-File -FilePath (Join-Path $outDir "05-schema-prisma.txt") -Encoding utf8
}

# 6) Environment file presence only
$envReport = @()
$envReport += "ENV FILE CHECK"
$envReport += "=============="
foreach ($name in @(".env", ".env.local", ".env.production", ".env.example")) {
    if (Test-Path $name) {
        $envReport += "$name FOUND"
    } else {
        $envReport += "$name MISSING"
    }
}
Write-File -Path (Join-Path $outDir "06-env-check.txt") -Lines $envReport

# 7) Build / type / lint checks
$checksPath = Join-Path $outDir "07-checks.txt"
"BUILD / TYPE / LINT" | Out-File -FilePath $checksPath -Encoding utf8
"===================" | Out-File -FilePath $checksPath -Append -Encoding utf8

"`nNODE VERSION" | Out-File -FilePath $checksPath -Append -Encoding utf8
node -v 2>&1 | Out-File -FilePath $checksPath -Append -Encoding utf8

"`nPNPM VERSION" | Out-File -FilePath $checksPath -Append -Encoding utf8
pnpm -v 2>&1 | Out-File -FilePath $checksPath -Append -Encoding utf8

"`nPNPM BUILD" | Out-File -FilePath $checksPath -Append -Encoding utf8
pnpm build 2>&1 | Out-File -FilePath $checksPath -Append -Encoding utf8

if (Test-Path ".\tsconfig.json") {
    "`nTSC NO EMIT" | Out-File -FilePath $checksPath -Append -Encoding utf8
    npx tsc --noEmit 2>&1 | Out-File -FilePath $checksPath -Append -Encoding utf8
}

"`nPNPM LINT" | Out-File -FilePath $checksPath -Append -Encoding utf8
pnpm lint 2>&1 | Out-File -FilePath $checksPath -Append -Encoding utf8

# 8) Large files
$largePath = Join-Path $outDir "08-large-files.txt"
"LARGE FILES > 5MB" | Out-File -FilePath $largePath -Encoding utf8
"=================" | Out-File -FilePath $largePath -Append -Encoding utf8
Get-ChildItem "." -Recurse -File |
    Where-Object { $_.Length -gt 5MB } |
    Sort-Object Length -Descending |
    Select-Object FullName, Length |
    Format-Table -AutoSize |
    Out-String |
    Out-File -FilePath $largePath -Append -Encoding utf8

Write-Host ""
Write-Host "Done. Output folder:"
Write-Host $outDir
Write-Host ""
Write-Host "Files created:"
Get-ChildItem $outDir | Select-Object Name