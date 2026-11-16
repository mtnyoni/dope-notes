$envFile = Join-Path (Split-Path $PSScriptRoot) '.env'
if (-not $env:DOPE_NOTES_GITHUB_CLIENT_ID -and (Test-Path $envFile)) {
    foreach ($line in Get-Content $envFile) {
        if ($line -match '^\s*DOPE_NOTES_GITHUB_CLIENT_ID\s*=\s*["'']?([A-Za-z0-9_]*)["'']?\s*$') {
            $env:DOPE_NOTES_GITHUB_CLIENT_ID = $Matches[1]
        }
    }
}
if ($env:DOPE_NOTES_GITHUB_CLIENT_ID -and $env:DOPE_NOTES_GITHUB_CLIENT_ID -notmatch '^[A-Za-z0-9_]+$') {
    throw 'Use the public GitHub OAuth Client ID, not a secret.'
}
