[CmdletBinding(SupportsShouldProcess = $true)]
Param(
    [switch]$KeepDemoState,
    [switch]$KeepVenv,
    [switch]$KeepCaches,
    [switch]$KeepDownloads
)

$ErrorActionPreference = "Stop"

function Normalize-DemoDayPath {
    param([Parameter(Mandatory)][string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    while ($Path -match '^[^:]+::') {
        $Path = $Path.Substring($matches[0].Length)
    }

    try {
        $Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    }
    catch {
    }

    $uncExtendedPrefix = '\\?\UNC\'
    if ($Path.StartsWith($uncExtendedPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return '\\' + $Path.Substring($uncExtendedPrefix.Length)
    }

    $extendedPrefix = '\\?\'
    if ($Path.StartsWith($extendedPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $Path.Substring($extendedPrefix.Length)
    }

    return $Path
}

function Remove-DemoDayDirectory {
    param([Parameter(Mandatory)][string]$Path)

    $Path = Normalize-DemoDayPath -Path $Path

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    try {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        return
    }
    catch {
    }

    $wslDistro = $null
    $wslLinuxPath = $null
    $wslPrefix = '\\wsl.localhost' + [char]92
    if ($Path.StartsWith($wslPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        $afterPrefix = $Path.Substring($wslPrefix.Length)
        $idx = $afterPrefix.IndexOf('\')
        if ($idx -gt 0) {
            $wslDistro = $afterPrefix.Substring(0, $idx)
            $wslLinuxPath = "/" + ($afterPrefix.Substring($idx + 1) -creplace '\\', '/')
        }
    }
    elseif ($Path -like '\\wsl$\*') {
        $afterPrefix = $Path.Substring(7)
        $idx = $afterPrefix.IndexOf('\')
        if ($idx -gt 0) {
            $wslDistro = $afterPrefix.Substring(0, $idx)
            $wslLinuxPath = "/" + ($afterPrefix.Substring($idx + 1) -creplace '\\', '/')
        }
    }
    if ($null -ne $wslDistro -and -not [string]::IsNullOrWhiteSpace($wslLinuxPath)) {
        Write-Host "[cleanup-demo] removing directory via WSL ($wslDistro): $wslLinuxPath"
        & wsl.exe -d $wslDistro -- rm -rf -- $wslLinuxPath
        if (-not (Test-Path -LiteralPath $Path)) {
            return
        }
    }

    if (-not ($Path.StartsWith('\\'))) {
        $qPath = '"' + ($Path -replace '"', '""') + '"'
        $prevEa = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'SilentlyContinue'
            $null = & cmd.exe /c "rmdir /s /q $qPath" 2>&1
        }
        finally {
            $ErrorActionPreference = $prevEa
        }
        if (-not (Test-Path -LiteralPath $Path)) {
            return
        }
    }

    try {
        Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue |
            Sort-Object { $_.FullName.Length } -Descending |
            ForEach-Object {
                $childPath = Normalize-DemoDayPath -Path $_.FullName
                Remove-Item -LiteralPath $childPath -Force -Recurse -ErrorAction SilentlyContinue
            }
        Remove-Item -LiteralPath $Path -Force -Recurse -ErrorAction Stop
        return
    }
    catch {
    }

    if (Test-Path -LiteralPath $Path) {
        throw "[cleanup-demo] ERROR: could not remove directory: $Path"
    }
}

function Remove-DemoDayPath {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Label,
        [switch]$QuietMissing
    )

    $Path = Normalize-DemoDayPath -Path $Path
    if (-not (Test-Path -LiteralPath $Path)) {
        if (-not $QuietMissing) {
            Write-Host "[cleanup-demo] missing ${Label}: $Path"
        }
        return $false
    }

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if (-not $PSCmdlet.ShouldProcess($Path, "Remove $Label")) {
        return $false
    }

    if ($item.PSIsContainer) {
        Remove-DemoDayDirectory -Path $Path
    }
    else {
        Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
    }

    if (Test-Path -LiteralPath $Path) {
        throw "[cleanup-demo] ERROR: could not remove $Label at $Path"
    }

    Write-Host "[cleanup-demo] removed ${Label}: $Path"
    return $true
}

function Get-WslRepoContext {
    param([Parameter(Mandatory)][string]$Path)

    $normalizedPath = Normalize-DemoDayPath -Path $Path
    $wslPrefix = '\\wsl.localhost' + [char]92
    if (-not $normalizedPath.StartsWith($wslPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $null
    }

    $afterPrefix = $normalizedPath.Substring($wslPrefix.Length)
    $parts = $afterPrefix.Split([char]92, [System.StringSplitOptions]::RemoveEmptyEntries)
    if ($parts.Length -lt 2) {
        return $null
    }

    $context = [ordered]@{
        Distro = $parts[0]
        UserHomeUnc = $null
        UserHomeLinux = $null
    }

    if (($parts.Length -ge 3) -and ($parts[1] -eq 'home')) {
        $username = $parts[2]
        $context.UserHomeUnc = '\\wsl.localhost\' + $parts[0] + '\\home\\' + $username
        $context.UserHomeLinux = '/home/' + $username
    }

    return [PSCustomObject]$context
}

function Test-IsWindowsHost {
    if (Get-Variable -Name IsWindows -ErrorAction SilentlyContinue) {
        return [bool]$IsWindows
    }

    return ($env:OS -match 'Windows' -or [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT)
}

function Get-ConfiguredResetRoots {
    $rawRoots = $env:LOCKSMITH_EXTRA_RESET_ROOTS
    if ([string]::IsNullOrWhiteSpace($rawRoots)) {
        return @()
    }

    return @(
        $rawRoots -split "`r`n|`n|;" |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
}

function Get-DemoStateRoots {
    param([Parameter(Mandatory)][string]$RepoRoot)

    $roots = New-Object System.Collections.Generic.List[string]

    function Add-ExistingRoot {
        param([string]$Candidate)

        if ([string]::IsNullOrWhiteSpace($Candidate)) {
            return
        }

        $normalizedCandidate = Normalize-DemoDayPath -Path $Candidate
        if ((-not $roots.Contains($normalizedCandidate)) -and (Test-Path -LiteralPath $normalizedCandidate)) {
            $roots.Add($normalizedCandidate)
        }
    }

    if (Test-IsWindowsHost) {
        foreach ($candidate in @(
            (Join-Path $HOME ".keri"),
            "C:\usr\local\var\keri",
            "C:\ProgramData\keri"
        )) {
            Add-ExistingRoot -Candidate $candidate
        }

        $wslContext = Get-WslRepoContext -Path $RepoRoot
        if ($null -ne $wslContext) {
            foreach ($candidate in @(
                $(if ($wslContext.UserHomeUnc) { Join-Path $wslContext.UserHomeUnc ".keri" }),
                ('\\wsl.localhost\\' + $wslContext.Distro + '\\usr\\local\\var\\keri')
            )) {
                Add-ExistingRoot -Candidate $candidate
            }
        }

        foreach ($candidate in Get-ConfiguredResetRoots) {
            Add-ExistingRoot -Candidate $candidate
        }

        return $roots
    }

    foreach ($candidate in @(
        (Join-Path $HOME ".keri"),
        "/usr/local/var/keri",
        "/opt/homebrew/var/keri",
        "/var/keri"
    )) {
        Add-ExistingRoot -Candidate $candidate
    }

    foreach ($candidate in Get-ConfiguredResetRoots) {
        Add-ExistingRoot -Candidate $candidate
    }

    return $roots
}

function Reset-DemoState {
    param(
        [Parameter(Mandatory)][string]$LocksmithBase,
        [Parameter(Mandatory)][string]$RepoRoot
    )

    Write-Host "[cleanup-demo] clearing demo state for base '$LocksmithBase'"
    $roots = Get-DemoStateRoots -RepoRoot $RepoRoot
    if ($roots.Count -eq 0) {
        Write-Host "[cleanup-demo] no existing demo state roots found"
        Write-Host "[cleanup-demo] reset summary: removed=0 missing=0 failed=0"
        return
    }

    Write-Host "[cleanup-demo] reset roots: $($roots -join ', ')"

    $stores = @("db", "ks", "cf", "rt", "reg", "mbx", "not", "locksmith")

    $removedCount = 0
    $missingCount = 0
    $failedTargets = New-Object System.Collections.Generic.List[string]

    foreach ($root in $roots) {
        foreach ($store in $stores) {
            $target = Join-Path $root (Join-Path $store $LocksmithBase)
            try {
                if (Remove-DemoDayPath -Path $target -Label "demo state" -QuietMissing) {
                    $removedCount += 1
                }
                else {
                    $missingCount += 1
                }
            }
            catch {
                $failedTargets.Add($target)
                Write-Host "[cleanup-demo] WARNING: failed to remove $target"
            }
        }
    }

    Write-Host "[cleanup-demo] reset summary: removed=$removedCount missing=$missingCount failed=$($failedTargets.Count)"
    if ($failedTargets.Count -gt 0) {
        Write-Host "[cleanup-demo] WARNING: reset completed with failed removals. Ensure LockSmith is fully closed and retry."
    }
}

$repoRoot = Normalize-DemoDayPath -Path ((Resolve-Path (Join-Path $PSScriptRoot "..")).Path)
$locksmithBase = $env:LOCKSMITH_BASE
if ([string]::IsNullOrWhiteSpace($locksmithBase)) {
    $locksmithBase = "locksmith-demo"
}
$env:LOCKSMITH_BASE = $locksmithBase

Set-Location $repoRoot
Write-Host "[cleanup-demo] using LOCKSMITH_BASE=$locksmithBase"

if (-not $KeepVenv) {
    Remove-DemoDayPath -Path (Join-Path $repoRoot ".venv") -Label ".venv" | Out-Null
}

if (-not $KeepCaches) {
    Remove-DemoDayPath -Path (Join-Path $repoRoot ".pytest_cache") -Label ".pytest_cache" | Out-Null
    Remove-DemoDayPath -Path (Join-Path $repoRoot ".coverage") -Label ".coverage" | Out-Null
}

if (-not $KeepDownloads) {
    Remove-DemoDayPath -Path (Join-Path $repoRoot "libsodium_download.zip") -Label "libsodium_download.zip" | Out-Null
    Remove-DemoDayPath -Path (Join-Path $repoRoot "libsodium_temp") -Label "libsodium_temp" | Out-Null
}

if (-not $KeepDemoState) {
    Reset-DemoState -LocksmithBase $locksmithBase -RepoRoot $repoRoot
}

Write-Host "[cleanup-demo] cleanup complete"