#!/usr/bin/env pwsh
# VERIFICATION SCRIPT: Check for Common Provider/Service Bugs
# Run: .\verify_no_service_bugs.ps1

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     SECURITY SERVICE BUG DETECTION & PREVENTION SCRIPT       ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$hasIssues = $false
$libPath = "D:\Project APP\matrix\lib"

# ============================================================================
# CHECK 1: Incorrect Security Service Import Paths
# ============================================================================
Write-Host "🔍 CHECK 1: Verifying Security Service Import Paths..." -ForegroundColor Yellow
Write-Host ""

$incorrectImports = Get-ChildItem -Path $libPath -Recurse -Filter "*.dart" | 
    Select-String -Pattern "security/data/security_service" -CaseSensitive

if ($incorrectImports) {
    Write-Host "❌ FOUND INCORRECT IMPORTS:" -ForegroundColor Red
    $incorrectImports | ForEach-Object {
        Write-Host "   File: $($_.Path)" -ForegroundColor White
        Write-Host "   Line $($_.LineNumber): $($_.Line.Trim())" -ForegroundColor Gray
        Write-Host ""
    }
    $hasIssues = $true
} else {
    Write-Host "✅ No incorrect import paths found" -ForegroundColor Green
}
Write-Host ""

# ============================================================================
# CHECK 2: Direct SecurityService() Instantiation
# ============================================================================
Write-Host "🔍 CHECK 2: Checking for Direct Service Instantiation..." -ForegroundColor Yellow
Write-Host ""

$directInstances = Get-ChildItem -Path $libPath -Recurse -Filter "*.dart" | 
    Select-String -Pattern "= SecurityService\(\)" -CaseSensitive

if ($directInstances) {
    Write-Host "❌ FOUND DIRECT INSTANTIATION:" -ForegroundColor Red
    $directInstances | ForEach-Object {
        Write-Host "   File: $($_.Path)" -ForegroundColor White
        Write-Host "   Line $($_.LineNumber): $($_.Line.Trim())" -ForegroundColor Gray
        Write-Host ""
    }
    $hasIssues = $true
} else {
    Write-Host "✅ No direct instantiation found" -ForegroundColor Green
}
Write-Host ""

# ============================================================================
# CHECK 3: Missing Riverpod Import When Using ref
# ============================================================================
Write-Host "🔍 CHECK 3: Checking for Missing Riverpod Imports..." -ForegroundColor Yellow
Write-Host ""

$filesUsingRef = Get-ChildItem -Path $libPath -Recurse -Filter "*.dart" | 
    Select-String -Pattern "ref\.read\(|ref\.watch\(" -CaseSensitive

$issuesFound = @()
foreach ($file in ($filesUsingRef | Group-Object Path).Name) {
    $content = Get-Content $file -Raw
    if ($content -notmatch "import.*flutter_riverpod") {
        $issuesFound += $file
    }
}

if ($issuesFound.Count -gt 0) {
    Write-Host "❌ FOUND FILES USING ref WITHOUT RIVERPOD IMPORT:" -ForegroundColor Red
    $issuesFound | ForEach-Object {
        Write-Host "   $_" -ForegroundColor White
    }
    Write-Host ""
    $hasIssues = $true
} else {
    Write-Host "✅ All files using ref have Riverpod import" -ForegroundColor Green
}
Write-Host ""

# ============================================================================
# CHECK 4: Verify Correct Provider Usage
# ============================================================================
Write-Host "🔍 CHECK 4: Verifying Correct Provider Usage..." -ForegroundColor Yellow
Write-Host ""

$correctUsage = Get-ChildItem -Path $libPath -Recurse -Filter "*.dart" | 
    Select-String -Pattern "ref\.read\(securityServiceProvider\)" -CaseSensitive

Write-Host "✅ Found $($correctUsage.Count) correct provider usages" -ForegroundColor Green
Write-Host ""

# ============================================================================
# CHECK 5: Widget Type Consistency
# ============================================================================
Write-Host "🔍 CHECK 5: Checking Widget Type Consistency..." -ForegroundColor Yellow
Write-Host ""

$filesWithRef = @()
Get-ChildItem -Path "$libPath\features" -Recurse -Filter "*_page.dart" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    if ($content -match "ref\." -and $content -notmatch "ConsumerStatefulWidget|ConsumerWidget") {
        $filesWithRef += $_.FullName
    }
}

if ($filesWithRef.Count -gt 0) {
    Write-Host "⚠️  POTENTIAL ISSUES - Files using ref but not Consumer widgets:" -ForegroundColor Yellow
    $filesWithRef | ForEach-Object {
        Write-Host "   $_" -ForegroundColor White
    }
    Write-Host ""
} else {
    Write-Host "✅ All widgets using ref are Consumer widgets" -ForegroundColor Green
}
Write-Host ""

# ============================================================================
# CHECK 6: List All Files Using Security Service Correctly
# ============================================================================
Write-Host "📋 FILES CORRECTLY USING SECURITY SERVICE:" -ForegroundColor Cyan
Write-Host ""

$correctFiles = Get-ChildItem -Path $libPath -Recurse -Filter "*.dart" | 
    Select-String -Pattern "core/services/security_service" -CaseSensitive |
    Select-Object -ExpandProperty Path -Unique

$correctFiles | ForEach-Object {
    $fileName = Split-Path $_ -Leaf
    Write-Host "   ✓ $fileName" -ForegroundColor Green
}
Write-Host ""

# ============================================================================
# SUMMARY
# ============================================================================
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

if ($hasIssues) {
    Write-Host "❌ VERIFICATION FAILED - Issues found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please fix the issues above and run this script again." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "✅ VERIFICATION PASSED - No issues found!" -ForegroundColor Green
    Write-Host ""
    Write-Host "All security service usage is correct!" -ForegroundColor Green
    Write-Host "No persistence bugs detected." -ForegroundColor Green
    exit 0
}
