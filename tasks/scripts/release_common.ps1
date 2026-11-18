# Helpers shared by build_release.ps1 and publish_panel.ps1 (`DL-116`, `DL-141`).
# Dot-sourced: . "$PSScriptRoot\release_common.ps1"

# One line per refusal, naming a file or a key and never a value, so a log
# pasted into a chat cannot leak a secret.
function Stop-Release([string]$Script, [string]$Reason) {
    Write-Host "${Script}: $Reason"
    exit 1
}

# Parsed as Flutter parses an env file: blank and # lines skipped, split at the
# first '=', both sides trimmed.
function Read-EnvFile([string]$Path) {
    $values = @{}
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $values }
    foreach ($line in Get-Content -LiteralPath $Path) {
        $text = $line.Trim()
        if ($text -eq '' -or $text.StartsWith('#')) { continue }
        $at = $text.IndexOf('=')
        if ($at -lt 1) { continue }
        $values[$text.Substring(0, $at).Trim()] = $text.Substring($at + 1).Trim()
    }
    return $values
}

# A release is explained by one commit: a clean tree on a published main.
# Returns the full commit id.
function Assert-CleanMain([string]$Repo, [string]$Script) {
    $dirty = git -C $Repo status --porcelain --untracked-files=no
    if ($LASTEXITCODE -ne 0) { Stop-Release $Script 'git status failed' }
    if ($dirty) { Stop-Release $Script 'tracked files have uncommitted changes' }
    # An untracked file under frontend/ can still reach the bundle (an asset, a
    # source file); ignored files are not listed.
    $untracked = git -C $Repo status --porcelain -- frontend
    if ($LASTEXITCODE -ne 0) { Stop-Release $Script 'git status failed' }
    if ($untracked) { Stop-Release $Script 'frontend has untracked files' }
    # A release is built from a published commit, so the bundle can be explained
    # by anyone with the repository.
    git -C $Repo merge-base --is-ancestor HEAD origin/main
    if ($LASTEXITCODE -ne 0) { Stop-Release $Script 'HEAD is not on origin/main; a release is built from main (run git fetch first)' }
    return (git -C $Repo rev-parse HEAD).Trim()
}

# The server a build points at is fixed by one env file, named .env.<word>. The
# maps and firebase files never carry it. Returns the URL.
function Read-ApiBase([string]$Frontend, [string]$ApiEnv, [string]$Script) {
    if ($ApiEnv -cnotmatch '^\.env\.[a-z]+$') {
        Stop-Release $Script 'ApiEnv must be a file name like .env.release'
    }
    if ($ApiEnv -eq '.env.maps' -or $ApiEnv -eq '.env.firebase') {
        Stop-Release $Script "ApiEnv must not be $ApiEnv"
    }
    $values = Read-EnvFile (Join-Path $Frontend $ApiEnv)
    if (-not $values.ContainsKey('BB_API_BASE_URL') -or $values['BB_API_BASE_URL'] -eq '') {
        Stop-Release $Script "frontend/$ApiEnv has no BB_API_BASE_URL"
    }
    # -cnotmatch: PowerShell's -notmatch ignores case, and /API/V1 is not a route.
    if ($values['BB_API_BASE_URL'] -cnotmatch '^https://[a-z0-9-]+(\.[a-z0-9-]+)*\.[a-z]{2,}/api/v1$') {
        Stop-Release $Script "BB_API_BASE_URL in $ApiEnv must be https://<host>/api/v1"
    }
    return $values['BB_API_BASE_URL']
}
