# Narrow extraction-root selection for Brave's official uninstalled Windows ZIP.
# This deliberately never renames chrome.exe or accepts a setup program.
Set-StrictMode -Version Latest
function Find-BravePayloadDirectory {
    param([Parameter(Mandatory)][string]$ExtractRoot)
    if (-not (Test-Path -LiteralPath $ExtractRoot -PathType Container)) {
        throw "Missing extracted Brave ZIP directory: $ExtractRoot"
    }
    $braves = @(Get-ChildItem -LiteralPath $ExtractRoot -Recurse -File -Filter 'brave.exe' -ErrorAction Stop)
    if ($braves.Count -ne 1) {
        throw "Expected exactly one genuine brave.exe in official x64 ZIP, found $($braves.Count)"
    }
    return $braves[0].Directory.FullName
}
