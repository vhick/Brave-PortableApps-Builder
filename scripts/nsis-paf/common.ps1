Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Assert([bool]$Condition, [string]$Why) { if(-not $Condition) { throw $Why } }
function Get-7Zip {
    foreach($path in @('C:\Program Files\7-Zip\7z.exe','C:\Program Files (x86)\7-Zip\7z.exe')) {
        if(Test-Path -LiteralPath $path -PathType Leaf) { return $path }
    }
    $cmd=Get-Command 7z.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if($cmd) { return $cmd.Source }
    throw '7-Zip missing on Windows runner'
}
function Get-Makensis {
    foreach($path in @('C:\Program Files (x86)\NSIS\makensis.exe','C:\Program Files\NSIS\makensis.exe')) {
        if(Test-Path -LiteralPath $path -PathType Leaf) { return $path }
    }
    $cmd=Get-Command makensis.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if($cmd) { return $cmd.Source }
    throw 'makensis.exe missing; install NSIS 3.12.0 using the workflow'
}
function Assert-PE([string]$Path) {
    Assert (Test-Path -LiteralPath $Path -PathType Leaf) "Missing executable: $Path"
    $f=[IO.File]::OpenRead($Path)
    try {
        Assert ($f.Length -gt 64) "Too small to be PE: $Path"
        $reader=[IO.BinaryReader]::new($f)
        Assert ($reader.ReadUInt16() -eq 0x5A4D) "No MZ header: $Path"
        $f.Position=60
        $offset=$reader.ReadInt32()
        Assert ($offset -ge 64 -and $offset -lt ($f.Length - 4)) "Invalid PE header offset: $Path"
        $f.Position=$offset
        Assert ($reader.ReadUInt32() -eq 0x00004550) "No PE signature: $Path"
    } finally { $f.Dispose() }
}
function Test-ZipEntries([string]$ZipFile, [bool]$CheckPersonalData=$true) {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.ZipFile
    $archive=[IO.Compression.ZipFile]::OpenRead($ZipFile)
    try {
        $names=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $fileCount=0
        foreach($entry in $archive.Entries) {
            $name=$entry.FullName.Replace('\','/')
            Assert (-not [string]::IsNullOrWhiteSpace($name)) 'Blank ZIP entry'
            Assert ($name.StartsWith('BravePortable/',[StringComparison]::OrdinalIgnoreCase)) "Unexpected ZIP root: $name"
            Assert (-not $name.StartsWith('/')) "Absolute ZIP entry: $name"
            Assert (-not $name.Contains(':')) "Drive or NTFS ADS entry: $name"
            Assert (-not (($name -split '/') -contains '..')) "Parent traversal entry: $name"
            Assert ($names.Add($name)) "Duplicate ZIP member name: $name"
            $type=(($entry.ExternalAttributes -shr 16) -band 0xF000)
            Assert ($type -ne 0xA000) "Symlink ZIP entry unsupported: $name"
            if(-not $name.EndsWith('/')) {
                $fileCount++
                if($CheckPersonalData -and $name -match '(?i)^BravePortable/Data/') {
                    throw "Portable ZIP unexpectedly contains Data file: $name"
                }
            }
        }
        Assert ($fileCount -gt 0) 'ZIP contains no files'
        foreach($required in @('BravePortable/BravePortable.exe','BravePortable/App/Brave/brave.exe','BravePortable/App/AppInfo/appinfo.ini','BravePortable/App/AppInfo/appicon.ico')) {
            Assert ($names.Contains($required)) "Missing ZIP payload: $required"
        }
    } finally { $archive.Dispose() }
}
function Assert-Staging([string]$Folder) {
    foreach($file in @('BravePortable.exe','App/Brave/brave.exe','App/AppInfo/appinfo.ini','App/AppInfo/appicon.ico','Other/Source/upstream.json')) {
        Assert (Test-Path -LiteralPath (Join-Path $Folder $file) -PathType Leaf) "Missing staged file: $file"
    }
    Assert-PE (Join-Path $Folder 'BravePortable.exe')
    Assert-PE (Join-Path $Folder 'App/Brave/brave.exe')
    $meta=Get-Content -LiteralPath (Join-Path $Folder 'App/AppInfo/appinfo.ini') -Raw
    Assert ($meta -match '(?m)^AppID=BravePortableIndependent\s*$') 'Unexpected AppID'
    Assert ($meta -match '(?m)^Start=BravePortable\.exe\s*$') 'Unexpected launcher entry'
    $data=Join-Path $Folder 'Data'
    if(Test-Path -LiteralPath $data) {
        $files=@(Get-ChildItem -LiteralPath $data -File -Force -Recurse)
        Assert ($files.Count -eq 0) 'Staged Data contains files; refusing to embed browser user data'
    }
}
function Invoke-Bounded([string]$Exe, [string[]]$Arguments, [string]$Log, [int]$Seconds) {
    $psi=[Diagnostics.ProcessStartInfo]::new()
    $psi.FileName=$Exe
    foreach($arg in $Arguments) { [void]$psi.ArgumentList.Add($arg) }
    $psi.UseShellExecute=$false
    $psi.CreateNoWindow=$true
    $psi.RedirectStandardOutput=$true
    $psi.RedirectStandardError=$true
    $p=[Diagnostics.Process]::Start($psi)
    try {
        $stdout=$p.StandardOutput.ReadToEndAsync()
        $stderr=$p.StandardError.ReadToEndAsync()
        if(-not $p.WaitForExit($Seconds*1000)) {
            try { $p.Kill($true) } catch {}
            try { $p.WaitForExit(5000) | Out-Null } catch {}
            "Process exceeded ${Seconds}s: $Exe. Process was terminated by the build watchdog." | Set-Content -LiteralPath $Log -Encoding utf8
            throw "Process exceeded ${Seconds}s: $Exe. See $Log"
        }
        $completed=[Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($stdout,$stderr),30000)
        Assert $completed 'Compiler output streams did not close within 30 seconds'
        "$($stdout.Result)`n--- STDERR ---`n$($stderr.Result)" | Set-Content -LiteralPath $Log -Encoding utf8
        Assert ($p.ExitCode -eq 0) "Command failed ($($p.ExitCode)): $Exe; see $Log"
    } finally { $p.Dispose() }
}
