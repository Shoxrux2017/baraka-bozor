<#
.SYNOPSIS
  Builds the signed Android release bundle from a clean commit (`DL-116`).

.DESCRIPTION
  Refuses a modified tree, a pubspec version without a build number, an
  incomplete key.properties or env file, and a bundle that is not signed with
  the upload key. Prints names and fingerprints only, never a value.

  Usage: powershell -File tasks/scripts/build_release.ps1 [-OutDir <path>]
           [-ApiEnv <.env.name>] [-Apk]

  -ApiEnv  the frontend env file that fixes the API server (default
           .env.release); never .env.maps or .env.firebase.
  -Apk     builds a signed APK (barakabozor-<version>+<code>-<api host>.apk)
           instead of the bundle, for testers (`DL-141` (9)).
#>
param(
    [string]$OutDir,
    [string]$ApiEnv = '.env.release',
    [switch]$Apk
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\release_common.ps1"

function Stop-Build([string]$Reason) { Stop-Release 'build_release' $Reason }

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

# apksigner prints lower-case hex without colons; keytool prints upper case
# with colons. The summary keeps keytool's form.
function Format-Fingerprint([string]$Hex) {
    $plain = $Hex.Replace(':', '').ToUpperInvariant()
    return (($plain -split '(?<=\G..)(?!$)') -join ':')
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
$commit = Assert-CleanMain $repo 'build_release'

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
$apiBase = Read-ApiBase $frontend $ApiEnv 'build_release'
$apiHost = ([Uri]$apiBase).Host
$required = [ordered]@{
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
    if ($values.ContainsKey('BB_API_BASE_URL')) {
        # Flutter lets a later --dart-define-from-file win, so the server is
        # fixed by the API env file alone.
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
$dartDefines = @('--dart-define-from-file=.env.maps', '--dart-define-from-file=.env.firebase', "--dart-define-from-file=$ApiEnv")
Push-Location $frontend
try {
    if ($Apk) {
        flutter build apk --release @dartDefines
    }
    else {
        flutter build appbundle --release @dartDefines
    }
    $buildExit = $LASTEXITCODE
}
finally {
    Pop-Location
}
if ($buildExit -ne 0) { Stop-Build 'flutter build failed' }
if ($Apk) {
    $builtArtifact = Join-Path $frontend 'build/app/outputs/flutter-apk/app-release.apk'
    $extension = 'apk'
}
else {
    $builtArtifact = Join-Path $frontend 'build/app/outputs/bundle/release/app-release.aab'
    $extension = 'aab'
}
if (-not (Test-Path -LiteralPath $builtArtifact -PathType Leaf)) { Stop-Build 'flutter build failed' }

# Check 7: the artifact's signer must be the upload key. The password reaches
# keytool through the environment, never the command line, and is removed again.
$bundleSha256 = $null
$bundleSha1 = $null
$bundleOwner = $null
if ($Apk) {
    # keytool -printcert -jarfile reads only v1 signatures; an APK is verified
    # by apksigner, from the newest build-tools of the Android SDK.
    $apksigner = $null
    $sdkRoots = @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT)
    if ($env:LOCALAPPDATA) { $sdkRoots += (Join-Path $env:LOCALAPPDATA 'Android\Sdk') }
    foreach ($sdk in $sdkRoots) {
        if (-not $sdk) { continue }
        $tools = Join-Path $sdk 'build-tools'
        if (-not (Test-Path -LiteralPath $tools -PathType Container)) { continue }
        $newest = Get-ChildItem -LiteralPath $tools -Directory |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'apksigner.bat') } |
            Sort-Object { try { [Version]$_.Name } catch { [Version]'0.0' } } |
            Select-Object -Last 1
        if ($newest) { $apksigner = Join-Path $newest.FullName 'apksigner.bat'; break }
    }
    if (-not $apksigner) { Stop-Build 'apksigner.bat not found in the Android SDK build-tools; set ANDROID_HOME' }
    $bundleOutput = @(& $apksigner verify --print-certs $builtArtifact)
    $bundleExit = $LASTEXITCODE
    foreach ($line in $bundleOutput) {
        if (-not $bundleSha256 -and $line -match '^Signer #1 certificate SHA-256 digest:\s*([0-9A-Fa-f:]+)\s*$') {
            $bundleSha256 = Format-Fingerprint $Matches[1]
        }
        elseif (-not $bundleSha1 -and $line -match '^Signer #1 certificate SHA-1 digest:\s*([0-9A-Fa-f:]+)\s*$') {
            $bundleSha1 = Format-Fingerprint $Matches[1]
        }
        elseif (-not $bundleOwner -and $line -match '^Signer #1 certificate DN:\s*(.*)$') {
            $bundleOwner = $Matches[1]
        }
    }
}
else {
    $bundleOutput = @(& $keytool '-J-Duser.language=en' -printcert -jarfile $builtArtifact)
    $bundleExit = $LASTEXITCODE
    $bundleSha256 = Get-Fingerprint $bundleOutput 'SHA256'
    $bundleSha1 = Get-Fingerprint $bundleOutput 'SHA1'
    foreach ($line in $bundleOutput) {
        if ($line -match '^\s*Owner:\s*(.*)$') { $bundleOwner = $Matches[1]; break }
    }
}
$env:BB_RELEASE_STOREPASS = $keys['storePassword']
try {
    $listOutput = @(& $keytool '-J-Duser.language=en' -list -v -keystore $storeFile -alias $keys['keyAlias'] '-storepass:env' BB_RELEASE_STOREPASS)
    $listExit = $LASTEXITCODE
}
finally {
    Remove-Item Env:BB_RELEASE_STOREPASS -ErrorAction SilentlyContinue
}
$keystoreSha256 = Get-Fingerprint $listOutput 'SHA256'
# apksigner prints no colons, keytool does: compare the bare hex.
if ($bundleExit -ne 0 -or $listExit -ne 0 -or -not $bundleSha256 -or -not $keystoreSha256 `
        -or $bundleSha256.Replace(':', '') -ne $keystoreSha256.Replace(':', '') `
        -or ($bundleOwner -and $bundleOwner.StartsWith('CN=Android Debug'))) {
    $what = if ($Apk) { 'the APK' } else { 'the bundle' }
    Stop-Build "$what is not signed with the upload key"
}

# Output: the artifact named after its version, and a summary that explains it.
if (-not $OutDir) { $OutDir = Join-Path $frontend 'build/release' }
$OutDir = (New-Item -ItemType Directory -Force -Path $OutDir).FullName
$baseName = "barakabozor-$versionName-$versionCode"
if ($Apk) { $baseName = "$baseName-$apiHost" }
$artifactPath = Join-Path $OutDir "$baseName.$extension"
Copy-Item -LiteralPath $builtArtifact -Destination $artifactPath -Force
$artifactSha256 = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
$summary = @(
    "version=$versionName+$versionCode"
    "commit=$commit"
    "built_at=$([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture))"
    "${extension}_sha256=$artifactSha256"
    "api_host=$apiHost"
    "signer_sha1=$bundleSha1"
    "signer_sha256=$bundleSha256"
)
$summaryPath = Join-Path $OutDir "$baseName.txt"
[IO.File]::WriteAllLines($summaryPath, [string[]]$summary)
$summary | ForEach-Object { Write-Host $_ }
exit 0
