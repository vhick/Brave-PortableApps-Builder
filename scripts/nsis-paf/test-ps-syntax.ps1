# Validate PowerShell syntax without executing any release/download/install script.
# This runs FIRST, before the workflow reaches preflight or release checking.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$scriptRoot = Join-Path $repoRoot 'scripts'
$files = @(Get-ChildItem -LiteralPath $scriptRoot -Filter '*.ps1' -Recurse -File)
if ($files.Count -lt 1) { throw 'No PowerShell scripts available for syntax validation' }
$failures = 0
foreach ($file in $files) {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    foreach ($syntaxError in @($errors)) {
        $failures++
        Write-Host "SYNTAX ERROR: $($file.FullName):$($syntaxError.Extent.StartLineNumber): $($syntaxError.Message)"
    }
}
if ($failures -gt 0) { throw "Found $failures PowerShell syntax error(s) in $($files.Count) scripts" }
Write-Host "PowerShell syntax validation PASSED: $($files.Count) scripts parsed; no script execution performed."
