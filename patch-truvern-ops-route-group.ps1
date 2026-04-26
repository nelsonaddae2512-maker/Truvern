# patch-truvern-ops-route-group.ps1
# Run from repo root:
#   powershell -ExecutionPolicy Bypass -File .\patch-truvern-ops-route-group.ps1
#
# What it does:
# 1) Creates app/(ops)/layout.tsx
# 2) Creates app/(ops)/truvern
# 3) Moves app/(app)/truvern/ops -> app/(ops)/truvern/ops
# 4) Backs up the original app/(app)/truvern folder first
# 5) Leaves URLs unchanged: /truvern/ops/*
#
# Why:
# app/(app)/truvern/ops/layout.tsx is currently nested under app/(app)/layout.tsx,
# so it still inherits Navbar + WorkspaceSidebar + Footer.
# Moving the route tree to a separate route group fixes that cleanly.

param(
  [string]$RepoRoot = "."
)

$ErrorActionPreference = "Stop"

function Ensure-Dir {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

function Write-Utf8File {
  param(
    [string]$Path,
    [string]$Content
  )
  $parent = Split-Path -Parent $Path
  if ($parent) { Ensure-Dir -Path $parent }
  [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

$root = (Resolve-Path -LiteralPath $RepoRoot).Path

$appGroupDir = Join-Path $root 'app\(app)'
$oldTruvernDir = Join-Path $appGroupDir 'truvern'
$oldOpsDir = Join-Path $oldTruvernDir 'ops'

$opsGroupDir = Join-Path $root 'app\(ops)'
$newTruvernDir = Join-Path $opsGroupDir 'truvern'
$newOpsDir = Join-Path $newTruvernDir 'ops'

if (-not (Test-Path -LiteralPath $oldOpsDir)) {
  throw "Expected source directory not found: $oldOpsDir"
}

Ensure-Dir -Path $opsGroupDir
Ensure-Dir -Path $newTruvernDir

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupRoot = Join-Path $root ".backups\truvern_ops_route_group_$timestamp"
Ensure-Dir -Path $backupRoot

# Backup the whole app/(app)/truvern subtree before changing anything
if (Test-Path -LiteralPath $oldTruvernDir) {
  Copy-Item -LiteralPath $oldTruvernDir -Destination (Join-Path $backupRoot 'truvern_from_app_group') -Recurse -Force
}

# Create the isolated (ops) group layout
$opsGroupLayoutPath = Join-Path $opsGroupDir 'layout.tsx'
$opsGroupLayoutContent = @'
// app/(ops)/layout.tsx
import React from "react";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

/**
 * Dedicated internal route-group shell for Truvern operations.
 *
 * IMPORTANT:
 * This route group exists specifically so /truvern/ops/* does NOT inherit
 * app/(app)/layout.tsx, which renders the customer Navbar, WorkspaceSidebar,
 * CommandPalette shell, and Footer.
 *
 * Keep this layout intentionally minimal and let nested ops layouts render
 * their own chrome.
 */
export default function OpsGroupLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return children;
}
'@
Write-Utf8File -Path $opsGroupLayoutPath -Content $opsGroupLayoutContent

# Guard against collisions
if (Test-Path -LiteralPath $newOpsDir) {
  throw "Destination already exists: $newOpsDir`nMove aborted to avoid overwriting files."
}

# Move the full ops tree out of (app) and into (ops)
Move-Item -LiteralPath $oldOpsDir -Destination $newOpsDir

# Clean up empty old truvern dir if applicable
$remaining = Get-ChildItem -LiteralPath $oldTruvernDir -Force -ErrorAction SilentlyContinue
if ($remaining -and $remaining.Count -eq 0) {
  Remove-Item -LiteralPath $oldTruvernDir -Force
}

Write-Host ""
Write-Host "Truvern ops route group patch applied." -ForegroundColor Green
Write-Host "Backup:" -ForegroundColor Yellow
Write-Host "  $backupRoot" -ForegroundColor Cyan
Write-Host ""
Write-Host "New route group layout:" -ForegroundColor Yellow
Write-Host "  app\(ops)\layout.tsx" -ForegroundColor Cyan
Write-Host ""
Write-Host "Moved route tree:" -ForegroundColor Yellow
Write-Host "  app\(app)\truvern\ops  ->  app\(ops)\truvern\ops" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1) Restart dev server"
Write-Host "     pnpm dev"
Write-Host "  2) Hard refresh the browser"
Write-Host "  3) Open /truvern/ops again"
Write-Host ""
Write-Host "Expected result:" -ForegroundColor Yellow
Write-Host "  /truvern/ops/* no longer inherits app/(app)/layout.tsx"
Write-Host "  Customer Navbar / WorkspaceSidebar / Footer should disappear."
