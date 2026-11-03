param([Parameter(Mandatory)][string]$Tag, [string]$Repository=$env:GITHUB_REPOSITORY)
. "$PSScriptRoot/common.ps1"
Assert ($Tag -match '^portable-v\d+\.\d+\.\d+-brave-r7-custom-nsis-paf-r1$') 'Unexpected output release tag'
Assert ($Repository -match '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') 'Invalid repository'
Assert (-not [string]::IsNullOrWhiteSpace($env:GH_TOKEN)) 'Missing GitHub token'
$uri="https://api.github.com/repos/$Repository/releases/tags/$Tag"
$headers=@{ Authorization="Bearer $env:GH_TOKEN"; Accept='application/vnd.github+json'; 'X-GitHub-Api-Version'='2022-11-28'; 'User-Agent'='brave-portable-nsis-packager' }
$response=Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -SkipHttpErrorCheck -StatusCodeVariable status -TimeoutSec 40
switch($status) {
  200 { Assert ($response.tag_name -ceq $Tag) 'Existing release has unexpected tag identity';
        "skip=true" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
        Write-Host "Existing release $Tag found: skipping without overwriting" }
  404 { "skip=false" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
        Write-Host "New release $Tag: proceeding without overwriting existing releases" }
  default { throw "GitHub release check failed HTTP $status; do not assume release missing" }
}
