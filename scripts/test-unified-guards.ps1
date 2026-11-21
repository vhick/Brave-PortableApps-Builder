# Fast regression test: [bool] Require arguments must be Boolean, not strings.
# Runs before any Brave download or NSIS compilation.
. "$PSScriptRoot/common.ps1"
Require (Test-NonBlank -value 'valid') 'Nonblank guard rejected a valid string'
Require (-not (Test-NonBlank -value '')) 'Nonblank guard accepted an empty string'
Require (-not (Test-NonBlank -value '   ')) 'Nonblank guard accepted whitespace'
Require (-not (Test-NonBlank -value $null)) 'Nonblank guard accepted null'
Require (Test-Sha256Hex -value ('a' * 64)) 'SHA-256 hex guard rejected valid lowercase digest'
Require (Test-Sha256Hex -value ('F' * 64)) 'SHA-256 hex guard rejected valid uppercase digest'
Require (-not (Test-Sha256Hex -value 'bad')) 'SHA-256 hex guard accepted malformed digest'
Require (-not (Test-Sha256Hex -value $null)) 'SHA-256 hex guard accepted null'
$temp=Join-Path ([IO.Path]::GetTempPath()) ('brave-guard-' + [guid]::NewGuid().ToString('N') + '.txt')
try {
  [IO.File]::WriteAllText($temp, 'Brave r10 guard test fixture')
  $real=(Get-FileHash -LiteralPath $temp -Algorithm SHA256).Hash
  Require (Test-Sha256Hex -value $real) 'Real Get-FileHash result was not accepted'
  Write-Host 'PASS: correct Boolean argument types for SHA-256 and environment guards'
} finally {
  if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
}
