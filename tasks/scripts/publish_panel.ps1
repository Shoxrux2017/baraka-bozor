<#
.SYNOPSIS
  Builds the web panel from a clean main and publishes it to the test stand (`DL-141` (9)).

.DESCRIPTION
  Refuses a modified tree or a HEAD that is not on origin/main, builds
  `flutter build web --release` against the API named by -ApiEnv, uploads the
  archive to /opt/barakabozor/panel/incoming over ssh/scp, extracts it into
  panel/releases/<name>, moves the relative link panel/current to it, keeps the
  newest three older releases and checks the link. Prints names, never a value.

  Usage: powershell -File tasks/scripts/publish_panel.ps1 -SshTarget <user@host>
           [-ApiEnv <.env.name>] [-Identity <key path>]

  -ApiEnv    the frontend env file that fixes the API server (default
             .env.release); never .env.maps or .env.firebase.
  -Identity  the ssh key (default $HOME\.ssh\barakabozor_vps).
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$SshTarget,
    [string]$ApiEnv = '.env.release',
    [string]$Identity = (Join-Path $HOME '.ssh\barakabozor_vps')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\release_common.ps1"

function Stop-Publish([string]$Reason) { Stop-Release 'publish_panel' $Reason }

$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$frontend = Join-Path $repo 'frontend'
$remoteHome = '/opt/barakabozor'

if ($SshTarget -cnotmatch '^[A-Za-z0-9._-]+@[A-Za-z0-9._-]+$') { Stop-Publish 'SshTarget must be <user>@<host>' }

# Check 1: a panel must be explained by one commit.
$commit = Assert-CleanMain $repo 'publish_panel'

# Check 2: the API server comes from the env file alone.
$apiBase = Read-ApiBase $frontend $ApiEnv 'publish_panel'
$apiHost = ([Uri]$apiBase).Host

# Check 3: the tools.
if (-not (Test-Path -LiteralPath $Identity -PathType Leaf)) { Stop-Publish 'the ssh key named by -Identity does not exist' }
$openSsh = Join-Path $env:SystemRoot 'System32\OpenSSH'
$ssh = Join-Path $openSsh 'ssh.exe'
$scp = Join-Path $openSsh 'scp.exe'
$tar = Join-Path $env:SystemRoot 'System32\tar.exe'
foreach ($tool in $ssh, $scp, $tar) {
    if (-not (Test-Path -LiteralPath $tool -PathType Leaf)) { Stop-Publish "$(Split-Path -Leaf $tool) not found under System32" }
}
$flutter = 'flutter'
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    $flutter = 'G:/tools/flutter/bin/flutter'
    if (-not (Test-Path -LiteralPath "$flutter.bat" -PathType Leaf)) { Stop-Publish 'flutter not found; put it on PATH' }
}

$shortSha = (git -C $repo rev-parse --short HEAD).Trim()
if ($LASTEXITCODE -ne 0) { Stop-Publish 'git rev-parse failed' }
$name = '{0}-{1}' -f [DateTime]::UtcNow.ToString('yyyyMMddHHmm', [Globalization.CultureInfo]::InvariantCulture), $shortSha

# Check 4: the build.
Push-Location $frontend
try {
    & $flutter build web --release "--dart-define-from-file=$ApiEnv"
    $buildExit = $LASTEXITCODE
}
finally {
    Pop-Location
}
if ($buildExit -ne 0) { Stop-Publish 'flutter build failed' }
$webDir = Join-Path $frontend 'build/web'
if (-not (Test-Path -LiteralPath (Join-Path $webDir 'index.html') -PathType Leaf)) { Stop-Publish 'flutter build failed' }

# Check 5: the archive and the upload.
$work = Join-Path ([IO.Path]::GetTempPath()) "bb-panel-$name"
New-Item -ItemType Directory -Force -Path $work | Out-Null
try {
    $archive = Join-Path $work "$name.tar.gz"
    & $tar -czf $archive -C $webDir .
    if ($LASTEXITCODE -ne 0) { Stop-Publish 'tar failed' }

    $sshOptions = @('-i', $Identity, '-o', 'BatchMode=yes')
    & $ssh @sshOptions $SshTarget "mkdir -p $remoteHome/panel/incoming"
    if ($LASTEXITCODE -ne 0) { Stop-Publish 'ssh failed to reach the server' }
    & $scp @sshOptions $archive "${SshTarget}:$remoteHome/panel/incoming/$name.tar.gz"
    if ($LASTEXITCODE -ne 0) { Stop-Publish 'scp failed' }

    # The remote part runs as one ssh with the script on stdin. LF endings: a
    # CR would reach bash as part of a command.
    $remote = @'
set -euo pipefail
name=$1
case "$name" in
    [0-9]*-[0-9a-f]*) ;;
    *) echo "publish_panel: bad release name" >&2; exit 1 ;;
esac
cd /opt/barakabozor/panel
mkdir -p releases
rm -rf "releases/.$name.tmp"
mkdir "releases/.$name.tmp"
tar -xzf "incoming/$name.tar.gz" -C "releases/.$name.tmp"
test -f "releases/.$name.tmp/index.html"
rm -rf "releases/$name"
mv "releases/.$name.tmp" "releases/$name"
ln -sfn "releases/$name" current.new
mv -Tf current.new current
rm -f "incoming/$name.tar.gz"
current=$(readlink current)
current=${current#releases/}
old=$(ls -1 releases | grep -v '^\.' | grep -vxF "$current" | sort | head -n -3 || true)
for dir in $old; do
    rm -rf "releases/$dir"
done
test "$(readlink current)" = "releases/$name"
echo "panel/current -> $(readlink current)"
'@
    $remotePath = Join-Path $work 'publish.sh'
    [IO.File]::WriteAllText($remotePath, ($remote -replace "`r`n", "`n") + "`n", (New-Object Text.UTF8Encoding($false)))

    $arguments = @('-i', ('"{0}"' -f $Identity), '-o', 'BatchMode=yes', $SshTarget, "`"bash -s -- $name`"")
    $process = Start-Process -FilePath $ssh -ArgumentList $arguments -RedirectStandardInput $remotePath `
        -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -ne 0) { Stop-Publish 'the remote step failed; panel/current may be unchanged' }
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "release=$name"
Write-Host "commit=$commit"
Write-Host "api_host=$apiHost"
Write-Host "server=$SshTarget"
exit 0
