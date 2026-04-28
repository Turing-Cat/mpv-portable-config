$ErrorActionPreference = 'Stop'

$Repo = Split-Path -Parent $PSScriptRoot

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Read-RepoFile {
    param([string]$RelativePath)

    return Get-Content -LiteralPath (Join-Path $Repo $RelativePath) -Raw
}

$requiredPaths = @(
    'base/mpv.conf',
    'base/input.conf',
    'platform/windows/mpv.conf',
    'platform/windows/fonts.conf',
    'platform/linux/mpv.conf',
    'setup.ps1',
    'setup.sh',
    'README.md'
)

foreach ($path in $requiredPaths) {
    Assert-True (Test-Path -LiteralPath (Join-Path $Repo $path)) "Missing required path: $path"
}

$rootPortableConfig = Read-RepoFile 'mpv.conf'
Assert-True ($rootPortableConfig -match '(?m)^gpu-api=d3d11$') 'Root portable mpv.conf should remain usable for local Windows portable mpv.'

$baseConfig = Read-RepoFile 'base/mpv.conf'
Assert-True ($baseConfig -match '(?m)^vo=gpu-next$') 'base/mpv.conf should keep common video output settings.'
Assert-True ($baseConfig -notmatch '(?m)^gpu-api=d3d11$') 'base/mpv.conf should not contain Windows-only gpu-api=d3d11.'

$windowsConfig = Read-RepoFile 'platform/windows/mpv.conf'
Assert-True ($windowsConfig -match '(?m)^gpu-api=d3d11$') 'platform/windows/mpv.conf should contain the Windows-only GPU API.'

$linuxConfig = Read-RepoFile 'platform/linux/mpv.conf'
Assert-True ($linuxConfig -notmatch '(?m)^gpu-api=d3d11$') 'platform/linux/mpv.conf should not force Direct3D.'

$testRoot = Join-Path $Repo '.test-output'
Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

$setup = Join-Path $Repo 'setup.ps1'

$linuxDest = Join-Path $testRoot 'linux'
& $setup -Platform linux -Dest $linuxDest -Force
$linuxMergedConfig = Get-Content -LiteralPath (Join-Path $linuxDest 'mpv.conf') -Raw
Assert-True ($linuxMergedConfig -match '(?m)^force-window=yes$') 'Linux install should include common base settings.'
Assert-True ($linuxMergedConfig -notmatch '(?m)^gpu-api=d3d11$') 'Linux install should not include Windows-only gpu-api=d3d11.'
Assert-True (Test-Path -LiteralPath (Join-Path $linuxDest 'input.conf')) 'Linux install should include input.conf.'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $linuxDest 'fonts.conf'))) 'Linux install should not copy Windows portable fonts.conf.'

$windowsDest = Join-Path $testRoot 'windows'
& $setup -Platform windows -Dest $windowsDest -Force
$windowsMergedConfig = Get-Content -LiteralPath (Join-Path $windowsDest 'mpv.conf') -Raw
Assert-True ($windowsMergedConfig -match '(?m)^force-window=yes$') 'Windows install should include common base settings.'
Assert-True ($windowsMergedConfig -match '(?m)^gpu-api=d3d11$') 'Windows install should include Windows-only gpu-api=d3d11.'
Assert-True (Test-Path -LiteralPath (Join-Path $windowsDest 'fonts.conf')) 'Windows install should include fonts.conf.'

$shellInstaller = Read-RepoFile 'setup.sh'
Assert-True ($shellInstaller -match 'compose_config') 'setup.sh should compose layerable config files instead of overwriting base config.'
Assert-True ($shellInstaller -match 'platform/linux') 'setup.sh should support Linux platform files.'
Assert-True ($shellInstaller -match 'platform/windows') 'setup.sh should support Windows platform files.'

Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
