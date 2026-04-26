param(
  [string]$Root = ".\app"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Normalize-Path([string]$p) {
  return ($p -replace "\\","/").Trim()
}

function Is-RouteFile($file) {
  $n = $file.Name.ToLowerInvariant()
  return $n -in @("page.tsx","page.ts","page.jsx","page.js","route.ts","route.js")
}

function To-RouteFromFile([string]$rootFull, [string]$fileFull) {
  $rel = $fileFull.Substring($rootFull.Length).TrimStart('\','/')
  $rel = Normalize-Path $rel

  $relDir = ($rel -replace '/(page|route)\.(tsx|ts|jsx|js)$','')
  $relDir = ($relDir -replace '\([^)]*\)','')
  $relDir = ($relDir -replace '/{2,}','/').Trim('/')

  if ([string]::IsNullOrWhiteSpace($relDir)) {
    return "/"
  }

  return "/" + $relDir
}

$rootFull = (Resolve-Path $Root).Path

$items = Get-ChildItem -Path $rootFull -Recurse -File |
  Where-Object { Is-RouteFile $_ } |
  ForEach-Object {
    $route = To-RouteFromFile $rootFull $_.FullName
    $kind = if ($_.Name -like "route.*") { "API" } else { "PAGE" }

    $relFile = Normalize-Path ($_.FullName.Substring($rootFull.Length).TrimStart('\','/'))

    [PSCustomObject]@{
      Kind  = $kind
      Route = $route
      File  = ("app/" + $relFile)
    }
  }

Write-Host ""
Write-Host "=== ROUTE COLLISIONS ==="

$collisions = $items |
  Where-Object { $_.Kind -eq "PAGE" } |
  Group-Object Route |
  Where-Object { $_.Count -gt 1 }

if (-not $collisions) {
  Write-Host "(none found)"
} else {
  foreach ($g in $collisions) {
    Write-Host ""
    Write-Host ("ROUTE: {0}" -f $g.Name)

    foreach ($m in $g.Group) {
      Write-Host ("  - {0}" -f $m.File)
    }
  }
}

Write-Host ""
Write-Host "=== ROUTE PAIRS ==="

$pairs = @(
"/trust-network",
"/trust-network-internal",
"/board-packet",
"/board-packet-internal",
"/board-report",
"/board-report-internal",
"/program-state"
)

foreach ($p in $pairs) {
  $exists = $items | Where-Object { $_.Route -eq $p }

  if ($exists) {
    Write-Host "$p  ✔"
  } else {
    Write-Host "$p  MISSING"
  }
}

Write-Host ""
Write-Host "Done."
