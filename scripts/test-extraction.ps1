. "$PSScriptRoot/common.ps1"
. "$PSScriptRoot/zip-utils.ps1"
$testRoot=Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString('N'))
$root=Join-Path $testRoot 'ziproot'
try {
    $nested=Join-Path (Join-Path $root 'brave-build') 'Application'
    $resources=Join-Path (Join-Path $nested 'assets') 'deep'
    New-Item -ItemType Directory -Force -Path $resources | Out-Null
    [IO.File]::WriteAllBytes((Join-Path $nested 'brave.exe'), [byte[]](77,90,0,0))
    [IO.File]::WriteAllText((Join-Path $resources 'resource.txt'),'keep me')
    New-Item -ItemType Directory -Force -Path (Join-Path $nested 'empty/tree') | Out-Null
    $found=Find-BravePayloadDirectory -ExtractRoot $root
    Require ($found -eq (Resolve-Path -LiteralPath $nested).Path) 'Nested Brave executable directory was not selected'
    $dest=Join-Path $testRoot 'payload'
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Get-ChildItem -LiteralPath $found -Force | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $dest -Recurse -Force }
    Require (Test-Path (Join-Path $dest 'assets/deep/resource.txt')) 'Nested browser support file lost on copy'
    Require (Test-Path (Join-Path $dest 'empty/tree') -PathType Container) 'Empty browser support directory lost on copy'
    New-Item -ItemType File -Path (Join-Path $root 'brave.exe') | Out-Null
    $rejected=$false
    try { $null=Find-BravePayloadDirectory -ExtractRoot $root } catch { $rejected=$true }
    Require $rejected 'Multiple candidate Brave executables must be rejected'
    Write-Host 'PASS: nested Brave ZIP root, complete resource-copy layout, empty directories, and ambiguous root rejection'
} finally {
    if(Test-Path -LiteralPath $testRoot){Remove-Item -LiteralPath $testRoot -Recurse -Force}
}
