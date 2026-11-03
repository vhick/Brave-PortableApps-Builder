# Interpret GitHub Releases API status codes strictly. This helper can be
# regression-tested without GitHub credentials or network access.
function Test-PortableReleaseStatus {
    param(
        [Parameter(Mandatory)][int]$StatusCode,
        [AllowNull()][object]$Response,
        [Parameter(Mandatory)][string]$ExpectedTag
    )
    if ($StatusCode -eq 404) {
        # A genuinely missing published release is normal on the first build.
        return $false
    }
    if ($StatusCode -ne 200) {
        # Crucial: 401/403/429/500 and other errors must NOT mean "no release".
        throw "GitHub release existence API returned HTTP $StatusCode for $ExpectedTag; refusing to assume it is absent."
    }
    if ($null -eq $Response) {
        throw "GitHub release lookup returned HTTP 200 without release metadata for $ExpectedTag."
    }
    $property=$Response.PSObject.Properties['tag_name']
    if ($null -eq $property -or [string]$property.Value -cne $ExpectedTag) {
        throw "GitHub release lookup returned the wrong tag or missing tag_name; expected $ExpectedTag."
    }
    return $true
}
