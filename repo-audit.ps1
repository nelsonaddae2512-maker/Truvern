# ===============================
# TRUVERN REPO AUDIT SCRIPT
# ===============================

Write-Host "==============================="
Write-Host " Truvern Repo Audit Starting..."
Write-Host "==============================="

$root = Get-Location
$output = "$root\repo_audit_output.txt"

# Reset output
if (Test-Path $output) {
    Remove-Item $output
}

function Section($title) {
    Add-Content $output "`n`n==============================="
    Add-Content $output " $title"
    Add-Content $output "==============================="
}

# ===============================
# BASIC INFO
# ===============================
Section "BASIC INFO"

Add-Content $output "Path: $root"
Add-Content $output "Date: $(Get-Date)"

# ===============================
# FULL REPO TREE (IMPORTANT)
# ===============================
Section "FULL REPO TREE"

tree /F /A | Out-File -Append $output

# ===============================
# NEXT.JS APP STRUCTURE
# ===============================
Section "APP ROUTES (app/ directory)"

if (Test-Path ".\app") {
    Get-ChildItem -Recurse -File .\app |
        Where-Object { $_.Name -match "page\.tsx|layout\.tsx|route\.ts" } |
        Select-Object FullName |
        Out-File -Append $output
}

# ===============================
# API ROUTES
# ===============================
Section "API ROUTES"

Get-ChildItem -Recurse -File . |
    Where-Object { $_.FullName -match "\\api\\.*route\.ts$" } |
    Select-Object FullName |
    Out-File -Append $output

# ===============================
# PRISMA CHECK
# ===============================
Section "PRISMA"

if (Test-Path ".\prisma\schema.prisma") {
    Add-Content $output "schema.prisma FOUND"
    Get-Content .\prisma\schema.prisma | Out-File -Append $output
} else {
    Add-Content $output "schema.prisma NOT FOUND"
}

# ===============================
# PACKAGE.JSON
# ===============================
Section "PACKAGE.JSON"

if (Test-Path ".\package.json") {
    Get-Content .\package.json | Out-File -Append $output
}

# ===============================
# ENV CHECK (NO SECRETS PRINTED)
# ===============================
Section "ENV FILE CHECK"

$envFiles = @(".env", ".env.local", ".env.production")

foreach ($file in $envFiles) {
    if (Test-Path $file) {
        Add-Content $output "$file FOUND"
    } else {
        Add-Content $output "$file MISSING"
    }
}

# ===============================
# BUILD TEST
# ===============================
Section "BUILD TEST"

try {
    Add-Content $output "Running build..."
    pnpm build 2>&1 | Out-File -Append $output
} catch {
    Add-Content $output "BUILD FAILED"
}

# ===============================
# TYPE CHECK (if available)
# ===============================
Section "TYPE CHECK"

if (Test-Path ".\tsconfig.json") {
    try {
        Add-Content $output "Running TypeScript check..."
        npx tsc --noEmit 2>&1 | Out-File -Append $output
    } catch {
        Add-Content $output "TS CHECK FAILED"
    }
}

# ===============================
# LINT CHECK (if available)
# ===============================
Section "LINT CHECK"

if (Test-Path ".\node_modules") {
    try {
        Add-Content $output "Running lint..."
        pnpm lint 2>&1 | Out-File -Append $output
    } catch {
        Add-Content $output "LINT FAILED"
    }
}

# ===============================
# LARGE FILES (RISK CHECK)
# ===============================
Section "LARGE FILES (>5MB)"

Get-ChildItem -Recurse -File |
    Where-Object { $_.Length -gt 5MB } |
    Select-Object FullName, Length |
    Out-File -Append $output

# ===============================
# NODE VERSION
# ===============================
Section "NODE VERSION"

node -v | Out-File -Append $output
pnpm -v | Out-File -Append $output

# ===============================
# DONE
# ===============================
Write-Host "==============================="
Write-Host " Audit Complete"
Write-Host " Output file:"
Write-Host $output
Write-Host "==============================="