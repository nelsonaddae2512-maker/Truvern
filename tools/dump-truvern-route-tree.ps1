param(
  [string]$Root = ".",
  [string]$OutDir = ".\repo-audit"
)

$ErrorActionPreference = "Stop"

# ---------- Helpers ----------

function Ensure-Dir {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

function Write-Section {
  param(
    [string]$Title,
    [string]$Content,
    [string]$FilePath
  )

  Add-Content -LiteralPath $FilePath -Value "`r`n" 
  Add-Content -LiteralPath $FilePath -Value ("=" * 100)
  Add-Content -LiteralPath $FilePath -Value $Title
  Add-Content -LiteralPath $FilePath -Value ("=" * 100)
  Add-Content -LiteralPath $FilePath -Value $Content
}

function Get-TreeLines {
  param([string]$BasePath)

  $items = Get-ChildItem -LiteralPath $BasePath -Recurse -Force |
    Where-Object {
      $_.FullName -notmatch "\\node_modules\\" -and
      $_.FullName -notmatch "\\.next\\" -and
      $_.FullName -notmatch "\\.git\\"
    } |
    Sort-Object FullName

  $lines = @()

  foreach ($item in $items) {
    $relative = $item.FullName.Substring((Resolve-Path $BasePath).Path.Length).TrimStart("\")
    $kind = if ($item.PSIsContainer) { "[DIR]" } else { "     " }
    $lines += "$kind $relative"
  }

  return $lines -join "`r`n"
}

function Get-FileSafe {
  param([string]$Path)

  if (Test-Path -LiteralPath $Path) {
    return Get-Content -LiteralPath $Path -Raw
  }

  return "[missing] $Path"
}

function Find-Files {
  param(
    [string]$BasePath,
    [string[]]$Patterns
  )

  Get-ChildItem -LiteralPath $BasePath -Recurse -Force -File |
    Where-Object {
      $_.FullName -notmatch "\\node_modules\\" -and
      $_.FullName -notmatch "\\.next\\" -and
      $_.FullName -notmatch "\\.git\\"
    } |
    Where-Object {
      $match = $false
      foreach ($p in $Patterns) {
        if ($_.Name -like $p) { $match = $true }
      }
      $match
    } |
    Sort-Object FullName |
    ForEach-Object {
      $_.FullName.Substring((Resolve-Path $BasePath).Path.Length).TrimStart("\")
    }
}

function Grep-Repo {
  param(
    [string]$BasePath,
    [string[]]$Needles
  )

  $results = @()

  $files = Get-ChildItem -LiteralPath $BasePath -Recurse -Force -File |
    Where-Object {
      $_.Extension -in @(".ts", ".tsx", ".js", ".jsx") -and
      $_.FullName -notmatch "\\node_modules\\" -and
      $_.FullName -notmatch "\\.next\\" -and
      $_.FullName -notmatch "\\.git\\"
    }

  foreach ($file in $files) {
    $relative = $file.FullName.Substring((Resolve-Path $BasePath).Path.Length).TrimStart("\")
    $content = Get-Content -LiteralPath $file.FullName

    for ($i = 0; $i -lt $content.Count; $i++) {
      foreach ($needle in $Needles) {
        if ($content[$i] -like "*$needle*") {
          # SAFE (no -f formatting issues)
          $results += ("{0}:{1}: {2}" -f $relative, ($i + 1), $content[$i].Trim())
        }
      }
    }
  }

  return ($results | Sort-Object -Unique) -join "`r`n"
}

# ---------- Run ----------

$rootPath = Resolve-Path $Root
$outPath = Join-Path $rootPath $OutDir
Ensure-Dir $outPath

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportFile = Join-Path $outPath "truvern_repo_audit_$timestamp.txt"

Set-Content $reportFile "Truvern Repo Audit - $timestamp"
Add-Content $reportFile "Root: $($rootPath.Path)"

# 1) Tree
$tree = Get-TreeLines -BasePath $rootPath.Path
Write-Section "REPO TREE SNAPSHOT" $tree $reportFile

# 2) Important files
$importantFiles = @(
  "app\(app)\layout.tsx",
  "app\(app)\truvern\ops\layout.tsx",
  "app\(app)\truvern\ops\page.tsx",
  "app\(app)\review-desk\reviews\[id]\page.tsx",
  "lib\truvern-ops-access.ts",
  "middleware.ts"
)

foreach ($file in $importantFiles) {
  $full = Join-Path $rootPath.Path $file
  Write-Section "FILE: $file" (Get-FileSafe $full) $reportFile
}

# 3) Route/Layout/Auth discovery
$routeFiles = Find-Files -BasePath $rootPath.Path -Patterns @(
  "layout.tsx",
  "page.tsx",
  "*auth*",
  "*clerk*",
  "middleware.ts"
)

Write-Section "ROUTE / LAYOUT / AUTH FILES" ($routeFiles -join "`r`n") $reportFile

# 4) High-signal grep
$grep = Grep-Repo -BasePath $rootPath.Path -Needles @(
  "TRUVERN_OPS_USERS",
  "requireTruvernOperator",
  "/truvern/ops",
  "auth(",
  "redirect",
  "Navbar",
  "WorkspaceSidebar"
)

Write-Section "HIGH-SIGNAL MATCHES" $grep $reportFile

# ---------- Done ----------

Write-Host ""
Write-Host "Repo audit created:" -ForegroundColor Green
Write-Host $reportFile -ForegroundColor Cyan
Write-Host ""
Write-Host "Open with:" -ForegroundColor Yellow
Write-Host "notepad `"$reportFile`""