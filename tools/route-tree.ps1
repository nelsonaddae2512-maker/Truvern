param(
  [string]$Root = ".\app",
  [switch]$IncludeApi = $false,
  [int]$MaxDepth = 12
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Normalize-Path([string]$p) { return ($p -replace "\\","/").Trim() }

function Is-RouteFile($file) {
  $n = $file.Name.ToLowerInvariant()
  return $n -in @("page.tsx","page.ts","page.jsx","page.js","route.ts","route.js")
}

function To-RouteFromFile([string]$rootFull, [string]$fileFull) {
  $rel = $fileFull.Substring($rootFull.Length).TrimStart('\','/')
  $rel = Normalize-Path $rel

  $isApi = $rel -match '/route\.(tsx|ts|jsx|js)$'
  $isPage = $rel -match '/page\.(tsx|ts|jsx|js)$'

  if (-not $isApi -and -not $isPage) { return $null }

  if ($isApi -and -not $IncludeApi) { return $null }

  $relDir = ($rel -replace '/(page|route)\.(tsx|ts|jsx|js)$','')
  $relDir = ($relDir -replace '\([^)]*\)','')   # strip route groups
  $relDir = ($relDir -replace '/{2,}','/').Trim('/')

  if ([string]::IsNullOrWhiteSpace($relDir)) { return "/" }
  return "/" + $relDir
}

# Simple trie node
function New-Node { return [ordered]@{ children = @{} } }

function Add-Route($trie, [string]$route) {
  $r = $route.Trim()
  if ($r -eq "/") { $parts = @() } else { $parts = $r.Trim("/").Split("/") }

  $node = $trie
  foreach ($p in $parts) {
    if (-not $node.children.Contains($p)) {
      $node.children[$p] = (New-Node)
    }
    $node = $node.children[$p]
  }
}

function Sort-Key([string]$s) {
  # Keep dynamic segments grouped, and route groups already removed.
  if ($s -match '^\[\.\.\..+\]$') { return "zz3_$s" }   # catch-all last
  if ($s -match '^\[.+\]$') { return "zz2_$s" }         # dynamic after static
  return "aa_$s"
}

function Print-Tree($node, [string]$prefix, [int]$depth) {
  if ($depth -gt $MaxDepth) { return }

  $keys = @($node.children.Keys | Sort-Object { Sort-Key $_ })
  for ($i=0; $i -lt $keys.Count; $i++) {
    $k = $keys[$i]
    $isLast = ($i -eq $keys.Count - 1)

    $branch = if ($isLast) { "└─ " } else { "├─ " }
    Write-Host ($prefix + $branch + $k)

    $nextPrefix = $prefix + ($(if ($isLast) { "   " } else { "│  " }))
    Print-Tree $node.children[$k] $nextPrefix ($depth + 1)
  }
}

$rootFull = (Resolve-Path $Root).Path
$trie = New-Node

Get-ChildItem -Path $rootFull -Recurse -File |
  Where-Object { Is-RouteFile $_ } |
  ForEach-Object {
    $r = To-RouteFromFile $rootFull $_.FullName
    if ($r) { Add-Route $trie $r }
  }

Write-Host ""
Write-Host "Next.js Route Tree"
Write-Host ("Root: " + $rootFull)
Write-Host ("IncludeApi: " + $IncludeApi)
Write-Host ""

Write-Host "/"
Print-Tree $trie "" 0

Write-Host ""
Write-Host "Done."
