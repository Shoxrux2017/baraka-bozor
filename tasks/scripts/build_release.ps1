<#
.SYNOPSIS
  Builds the signed Android release bundle from a clean commit (`DL-116`).

.DESCRIPTION
  Refuses a modified tree, a pubspec version without a build number, an
  incomplete key.properties or env file, and a bundle that is not signed with
  the upload key. Prints names and fingerprints only, never a value.

  Usage: powershell -File tasks/scripts/build_release.ps1 [-OutDir <path>]
#>
param(
    [string]$OutDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# One line per refusal, naming a file or a key and never a value, so a log
# pasted into a chat cannot leak a secret.
function Stop-Build([string]$Reason) {
    Write-Host "build_release: $Reason"
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

# Parsed like the Gradle build reads it: the value starts after the first '='
# with leading blanks dropped.
function Read-KeyProperties([string]$Path) {
    $values = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        $text = $line.TrimStart()
        if ($text -eq '' -or $text.StartsWith('#') -or $text.StartsWith('!')) { continue }
        $at = $text.IndexOf('=')
        if ($at -lt 1) { continue }
        $values[$text.Substring(0, $at).Trim()] = $text.Substring($at + 1).TrimStart()
    }
    return $values
}

function Get-Fingerprint([string[]]$Output, [string]$Algorithm) {
    foreach ($line in $Output) {
        if ($line -match ('^\s*' + $Algorithm + ':\s*([0-9A-Fa-f:]+)\s*$')) {
            return $Matches[1].ToUpperInvariant()
        }
    }
    return $null
}

$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$frontend = Join-Path $repo 'frontend'

# Check 1: a bundle must be explained by one commit.
$dirty = git -C $repo status --porcelain --untracked-files=no
if ($LASTEXITCODE -ne 0) { Stop-Build 'git status failed' }
if ($dirty) { Stop-Build 'tracked files have uncommitted changes' }
# An untracked file under frontend/ can still reach the bundle (an asset, a
# source file); ignored files are not listed.
$untracked = git -C $repo status --porcelain -- frontend
if ($LASTEXITCODE -ne 0) { Stop-Build 'git status failed' }
if ($untracked) { Stop-Build 'frontend has untracked files' }
# A release is built from a published commit, so the bundle can be explained
# by anyone with the repository.
git -C $repo merge-base --is-ancestor HEAD origin/main
if ($LASTEXITCODE -ne 0) { Stop-Build 'HEAD is not on origin/main; a release is built from main (run git fetch first)' }
$commit = (git -C $repo rev-parse HEAD).Trim()

# Check 2: the version code comes only from pubspec.yaml (`DL-116` (2)).
$versionName = $null
$versionCode = $null
foreach ($line in Get-Content -LiteralPath (Join-Path $frontend 'pubspec.yaml')) {
    if ($line -match '^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$') {
        $versionName = $Matches[1]
        $versionCode = $Matches[2]
        break
    }
}
if (-not $versionName) { Stop-Build 'pubspec.yaml version must be x.y.z+N' }

# Check 3: the same three problems, worded as in android/app/build.gradle.kts.
$keyPropertiesPath = Join-Path $frontend 'android/key.properties'
$keyLabel = 'frontend/android/key.properties'
if (-not (Test-Path -LiteralPath $keyPropertiesPath -PathType Leaf)) {
    Stop-Build "${keyLabel}: the file is missing"
}
$keys = Read-KeyProperties $keyPropertiesPath
foreach ($name in 'storeFile', 'storePassword', 'keyAlias', 'keyPassword') {
    if (-not $keys.ContainsKey($name) -or [string]::IsNullOrWhiteSpace($keys[$name])) {
        Stop-Build "${keyLabel}: it has no $name"
    }
}
$storeFile = $keys['storeFile'].Trim()
if (-not [IO.Path]::IsPathRooted($storeFile)) {
    # Gradle resolves a relative storeFile against frontend/android/app.
    $storeFile = Join-Path (Join-Path $frontend 'android/app') $storeFile
}
if (-not (Test-Path -LiteralPath $storeFile -PathType Leaf)) {
    Stop-Build "${keyLabel}: the keystore its storeFile names does not exist"
}

# Check 4: a tester's build must never point at the wrong server.
$required = [ordered]@{
    '.env.release'  = @('BB_API_BASE_URL')
    '.env.maps'     = @('GOOGLE_MAPS_API_KEY')
    '.env.firebase' = @('FIREBASE_PROJECT_ID', 'FIREBASE_MESSAGING_SENDER_ID', 'FIREBASE_ANDROID_APP_ID', 'FIREBASE_ANDROID_API_KEY')
}
foreach ($file in $required.Keys) {
    $values = Read-EnvFile (Join-Path $frontend $file)
    foreach ($name in $required[$file]) {
        if (-not $values.ContainsKey($name) -or $values[$name] -eq '') {
            Stop-Build "frontend/$file has no $name"
        }
    }
    if ($file -eq '.env.release') {
        # -cnotmatch: PowerShell's -notmatch ignores case, and /API/V1 is not a route.
        if ($values['BB_API_BASE_URL'] -cnotmatch '^https://[a-z0-9-]+(\.[a-z0-9-]+)*\.[a-z]{2,}/api/v1$') {
            Stop-Build 'BB_API_BASE_URL in .env.release must be https://<host>/api/v1'
        }
        $apiHost = ([Uri]$values['BB_API_BASE_URL']).Host
    }
    elseif ($values.ContainsKey('BB_API_BASE_URL')) {
        # Flutter lets a later --dart-define-from-file win, so the server is
        # fixed by .env.release alone.
        Stop-Build "frontend/$file must not set BB_API_BASE_URL"
    }
}

# Check 5: keytool also proves the signer. Flutter's Gradle build needs a JDK
# too, so a JDK found only in Android Studio becomes JAVA_HOME for this process
# (`DL-116` (1)).
$studioJbr = 'C:\Program Files\Android\Android Studio\jbr'
$keytool = $null
if ($env:JAVA_HOME -and (Test-Path -LiteralPath (Join-Path $env:JAVA_HOME 'bin\keytool.exe'))) {
    $keytool = Join-Path $env:JAVA_HOME 'bin\keytool.exe'
}
if (-not $keytool) {
    $onPath = Get-Command keytool.exe -ErrorAction SilentlyContinue
    if ($onPath) { $keytool = $onPath.Source }
}
if (-not $keytool -and (Test-Path -LiteralPath (Join-Path $studioJbr 'bin\keytool.exe'))) {
    $keytool = Join-Path $studioJbr 'bin\keytool.exe'
    if (-not $env:JAVA_HOME) { $env:JAVA_HOME = $studioJbr }
}
if (-not $keytool) { Stop-Build 'keytool not found; set JAVA_HOME' }

# Check 6: the build.
Push-Location $frontend
try {
    flutter build appbundle --release '--dart-define-from-file=.env.maps' '--dart-define-from-file=.env.firebase' '--dart-define-from-file=.env.release'
    $buildExit = $LASTEXITCODE
}
finally {
    Pop-Location
}
if ($buildExit -ne 0) { Stop-Build 'flutter build failed' }
$builtBundle = Join-Path $frontend 'build/app/outputs/bundle/release/app-release.aab'
if (-not (Test-Path -LiteralPath $builtBundle -PathType Leaf)) { Stop-Build 'flutter build failed' }

# Check 7: the bundle's signer must be the upload key. The password reaches
# keytool through the environment, never the command line, and is removed again.
$bundleOutput = @(& $keytool '-J-Duser.language=en' -printcert -jarfile $builtBundle)
$bundleExit = $LASTEXITCODE
$bundleSha256 = Get-Fingerprint $bundleOutput 'SHA256'
$bundleSha1 = Get-Fingerprint $bundleOutput 'SHA1'
$env:BB_RELEASE_STOREPASS = $keys['storePassword']
try {
    $listOutput = @(& $keytool '-J-Duser.language=en' -list -v -keystore $storeFile -alias $keys['keyAlias'] '-storepass:env' BB_RELEASE_STOREPASS)
    $listExit = $LASTEXITCODE
}
finally {
    Remove-Item Env:BB_RELEASE_STOREPASS -ErrorAction SilentlyContinue
}
$keystoreSha256 = Get-Fingerprint $listOutput 'SHA256'
$bundleOwner = $null
foreach ($line in $bundleOutput) {
    if ($line -match '^\s*Owner:\s*(.*)$') { $bundleOwner = $Matches[1]; break }
}
if ($bundleExit -ne 0 -or $listExit -ne 0 -or -not $bundleSha256 -or -not $keystoreSha256 `
        -or $bundleSha256 -ne $keystoreSha256 `
        -or ($bundleOwner -and $bundleOwner.StartsWith('CN=Android Debug'))) {
    Stop-Build 'the bundle is not signed with the upload key'
}

# Output: the bundle named after its version, and a summary that explains it.
if (-not $OutDir) { $OutDir = Join-Path $frontend 'build/release' }
$OutDir = (New-Item -ItemType Directory -Force -Path $OutDir).FullName
$baseName = "barakabozor-$versionName-$versionCode"
$bundlePath = Join-Path $OutDir "$baseName.aab"
Copy-Item -LiteralPath $builtBundle -Destination $bundlePath -Force
$aabSha256 = (Get-FileHash -LiteralPath $bundlePath -Algorithm SHA256).Hash.ToLowerInvariant()
$summary = @(
    "version=$versionName+$versionCode"
    "commit=$commit"
    "built_at=$([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture))"
    "aab_sha256=$aabSha256"
    "api_host=$apiHost"
    "signer_sha1=$bundleSha1"
    "signer_sha256=$bundleSha256"
)
$summaryPath = Join-Path $OutDir "$baseName.txt"
[IO.File]::WriteAllLines($summaryPath, [string[]]$summary)
$summary | ForEach-Object { Write-Host $_ }
exit 0
