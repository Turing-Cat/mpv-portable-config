[CmdletBinding()]
param(
    [ValidateSet('auto', 'windows', 'linux', 'macos')]
    [string]$Platform = 'auto',

    [string]$Dest,

    [switch]$Force,

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$LayeredConfigNames = @('mpv.conf', 'input.conf')
$Utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false

function Resolve-InstallPlatform {
    param([string]$RequestedPlatform)

    if ($RequestedPlatform -ne 'auto') {
        return $RequestedPlatform
    }

    if ($IsWindows -or $env:OS -eq 'Windows_NT') {
        return 'windows'
    }

    if ($IsLinux) {
        return 'linux'
    }

    if ($IsMacOS) {
        return 'macos'
    }

    throw 'Could not auto-detect platform. Pass -Platform windows, linux, or macos.'
}

function Get-DefaultDestination {
    param([string]$ResolvedPlatform)

    if ($ResolvedPlatform -eq 'windows') {
        if (-not [string]::IsNullOrWhiteSpace($env:APPDATA)) {
            return Join-Path $env:APPDATA 'mpv'
        }

        return Join-Path $HOME 'AppData\Roaming\mpv'
    }

    $xdgConfigHome = $env:XDG_CONFIG_HOME
    if ([string]::IsNullOrWhiteSpace($xdgConfigHome)) {
        $xdgConfigHome = Join-Path $HOME '.config'
    }

    return Join-Path $xdgConfigHome 'mpv'
}

function Assert-DestinationReady {
    param([string]$Destination)

    if ((Test-Path -LiteralPath $Destination) -and -not $Force) {
        $existingItem = Get-ChildItem -LiteralPath $Destination -Force -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $existingItem) {
            throw "Destination is not empty: $Destination. Re-run with -Force to overwrite managed files."
        }
    }

    if ($DryRun) {
        Write-Host "Would create destination: $Destination"
        return
    }

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
}

function Copy-TreeExceptLayeredConfig {
    param(
        [string]$Source,
        [string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        return
    }

    foreach ($item in Get-ChildItem -LiteralPath $Source -Force) {
        if ($LayeredConfigNames -contains $item.Name) {
            continue
        }

        if ($DryRun) {
            Write-Host "Would copy $($item.FullName) -> $Destination"
            continue
        }

        Copy-Item -LiteralPath $item.FullName -Destination $Destination -Recurse -Force
    }
}

function Compose-Config {
    param(
        [string]$FileName,
        [string]$ResolvedPlatform,
        [string]$Destination
    )

    $parts = @(
        (Join-Path $RepoRoot "base\$FileName"),
        (Join-Path $RepoRoot "platform\$ResolvedPlatform\$FileName")
    ) | Where-Object { Test-Path -LiteralPath $_ }

    if ($parts.Count -eq 0) {
        return
    }

    if ($DryRun) {
        Write-Host "Would compose_config $FileName from: $($parts -join ', ')"
        return
    }

    $chunks = foreach ($part in $parts) {
        $text = Get-Content -LiteralPath $part -Raw
        if (-not [string]::IsNullOrWhiteSpace($text)) {
            $text.TrimEnd()
        }
    }

    $target = Join-Path $Destination $FileName
    $content = ($chunks -join "`n`n") + "`n"
    [System.IO.File]::WriteAllText($target, $content, $Utf8NoBom)
}

$resolvedPlatform = Resolve-InstallPlatform $Platform
$destination = if ([string]::IsNullOrWhiteSpace($Dest)) {
    Get-DefaultDestination $resolvedPlatform
} else {
    $Dest
}

$baseDir = Join-Path $RepoRoot 'base'
$platformDir = Join-Path $RepoRoot "platform\$resolvedPlatform"

Assert-DestinationReady $destination
Copy-TreeExceptLayeredConfig $baseDir $destination
Copy-TreeExceptLayeredConfig $platformDir $destination

foreach ($configName in $LayeredConfigNames) {
    Compose-Config $configName $resolvedPlatform $destination
}

Write-Host "Installed mpv config for $resolvedPlatform to $destination"
