param(
  [string]$Root = ".",
  [string]$OutFile = "repo-tree.txt",
  [int]$MaxDepth = 8
)

$ErrorActionPreference = "Stop"

function Get-Indent {
  param([int]$Level)
  return ("|  " * $Level)
}

function Should-SkipDirectory {
  param([string]$Name)

  $skip = @(
    ".git",
    ".next",
    "node_modules",
    ".ignored_node_modules__bak",
    "dist",
    "build",
    "coverage",
    ".turbo",
    ".vercel",
    ".idea",
    ".vscode",
    "bin",
    "obj"
  )

  return $skip -contains $Name
}

function Should-SkipFile {
  param([System.IO.FileInfo]$File)

  $skipExtensions = @(
    ".log",
    ".tmp",
    ".cache",
    ".map",
    ".lock"
  )

  if ($skipExtensions -contains $File.Extension.ToLower()) {
    return $true
  }

  if ($File.Name -eq "pnpm-lock.yaml") {
    return $false
  }

  return $false
}

function Write-Tree {
  param(
    [string]$CurrentPath,
    [int]$Depth,
    [System.Collections.Generic.List[string]]$Lines
  )

  if ([string]::IsNullOrWhiteSpace($CurrentPath)) {
    return
  }

  if ($Depth -gt $MaxDepth) {
    return
  }

  $items = @(Get-ChildItem -LiteralPath $CurrentPath -Force -ErrorAction SilentlyContinue) |
    Where-Object {
      if ($_.PSIsContainer) {
        -not (Should-SkipDirectory -Name $_.Name)
      } else {
        -not (Should-SkipFile -File $_)
      }
    } |
    Sort-Object @{ Expression = { -not $_.PSIsContainer } }, Name

  foreach ($item in $items) {
    $prefix = Get-Indent -Level $Depth

    if ($item.PSIsContainer) {
      $Lines.Add("$prefix+ $($item.Name)\")
      Write-Tree -CurrentPath $item.FullName -Depth ($Depth + 1) -Lines $Lines
    }
    else {
      $Lines.Add("$prefix- $($item.Name)")
    }
  }
}

$resolvedRoot = Resolve-Path -LiteralPath $Root
$rootItem = Get-Item -LiteralPath $resolvedRoot

$lines = New-Object 'System.Collections.Generic.List[string]'
$lines.Add("Repository Tree")
$lines.Add("Root: $($rootItem.FullName)")
$lines.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$lines.Add("MaxDepth: $MaxDepth")
$lines.Add("")

$lines.Add("+ $($rootItem.Name)\")
Write-Tree -CurrentPath $rootItem.FullName -Depth 1 -Lines $lines

$lines | Set-Content -LiteralPath $OutFile -Encoding UTF8
$lines | ForEach-Object { Write-Host $_ }

Write-Host ""
Write-Host "Saved to: $OutFile"