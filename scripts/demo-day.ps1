Param(
    [string]$PythonBin = "",
    [switch]$SetupOnly,
    [switch]$NoAutoInstallUv,
    [switch]$ResetDemoState
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

    # Normalize extended Windows path prefixes so downstream Join-Path, Test-Path, and WSL mapping stay consistent.
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

function Format-DemoDayElapsed {
    param([Parameter(Mandatory)][TimeSpan]$Elapsed)

    return ('{0:00}:{1:00}' -f [int]$Elapsed.TotalMinutes, $Elapsed.Seconds)
}

function Join-DemoDayArguments {
    param([string[]]$ArgumentList = @())

    if (($null -eq $ArgumentList) -or ($ArgumentList.Count -eq 0)) {
        return ""
    }

    return [string]::Join(' ', ($ArgumentList | ForEach-Object {
        if ($_ -match '[\s"]') {
            '"' + ($_ -replace '"', '\"') + '"'
        }
        else {
            $_
        }
    }))
}

function Start-DemoDayProcess {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$ArgumentList = @()
    )

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $FilePath
    $startInfo.Arguments = Join-DemoDayArguments -ArgumentList $ArgumentList
    $startInfo.WorkingDirectory = (Get-Location).Path
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    $null = $process.Start()
    return $process
}

function Invoke-ExternalCommandWithHeartbeat {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [int]$HeartbeatSeconds = 8
    )

    $startedAt = Get-Date
    $process = Start-DemoDayProcess -FilePath $FilePath -ArgumentList $ArgumentList

    try {
        while (-not $process.WaitForExit($HeartbeatSeconds * 1000)) {
            $elapsed = (Get-Date) - $startedAt
            Write-Host "[demo-day] $Label still running... $(Format-DemoDayElapsed -Elapsed $elapsed) elapsed"
        }
    }
    finally {
        if (($null -ne $process) -and (-not $process.HasExited)) {
            $process.WaitForExit()
        }
    }

    if ($process.ExitCode -ne 0) {
        throw "[demo-day] ERROR: $Label failed (exit code $($process.ExitCode))"
    }

    $elapsed = (Get-Date) - $startedAt
    Write-Host "[demo-day] $Label finished in $(Format-DemoDayElapsed -Elapsed $elapsed)"
}

function Remove-DemoDayDirectoryWithHeartbeat {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Label,
        [int]$HeartbeatSeconds = 8
    )

    $Path = Normalize-DemoDayPath -Path $Path
    if (-not (Test-Path -LiteralPath $Path)) {
        return
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
        Write-Host "[demo-day] $Label via WSL ($wslDistro): $wslLinuxPath"
        $startedAt = Get-Date
        $process = Start-DemoDayProcess -FilePath "wsl.exe" -ArgumentList @("-d", $wslDistro, "--", "rm", "-rf", "--", $wslLinuxPath)

        try {
            while (-not $process.WaitForExit($HeartbeatSeconds * 1000)) {
                $elapsed = (Get-Date) - $startedAt
                Write-Host "[demo-day] $Label still running... $(Format-DemoDayElapsed -Elapsed $elapsed) elapsed"
            }
        }
        finally {
            if (($null -ne $process) -and (-not $process.HasExited)) {
                $process.WaitForExit()
            }
        }

        if (($process.ExitCode -eq 0) -and (-not (Test-Path -LiteralPath $Path))) {
            $elapsed = (Get-Date) - $startedAt
            Write-Host "[demo-day] $Label finished in $(Format-DemoDayElapsed -Elapsed $elapsed)"
            return
        }

        Write-Host "[demo-day] $Label needs fallback cleanup"
    }

    $startedAt = Get-Date
    Write-Host "[demo-day] $Label using PowerShell cleanup fallback"
    Remove-DemoDayDirectory -Path $Path
    $elapsed = (Get-Date) - $startedAt
    Write-Host "[demo-day] $Label finished in $(Format-DemoDayElapsed -Elapsed $elapsed)"
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
    }

    if (($parts.Length -ge 3) -and ($parts[1] -eq 'home')) {
        $username = $parts[2]
        $context.UserHomeUnc = '\\wsl.localhost\' + $parts[0] + '\\home\\' + $username
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

$repoRoot = Normalize-DemoDayPath -Path ((Resolve-Path (Join-Path $PSScriptRoot "..")).Path)
$autoInstallUv = -not $NoAutoInstallUv
$locksmithBase = $env:LOCKSMITH_BASE
if ([string]::IsNullOrWhiteSpace($locksmithBase)) {
    $locksmithBase = "locksmith-demo"
}
$env:LOCKSMITH_BASE = $locksmithBase

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
        # Remove-Item often fails on \\wsl.localhost\ or \\wsl$\ UNC paths (e.g. "directory is not empty").
    }

    # Prefer Linux-side delete when the repo is the WSL filesystem exposed over UNC (Remove-Item is unreliable there).
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
        Write-Host "[demo-day] removing directory via WSL ($wslDistro): $wslLinuxPath"
        & wsl.exe -d $wslDistro -- rm -rf -- $wslLinuxPath
        if (-not (Test-Path -LiteralPath $Path)) {
            return
        }
    }

    # cmd.exe does not support UNC paths well and stderr becomes a terminating NativeCommandError under $ErrorActionPreference = Stop.
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
        throw "[demo-day] ERROR: could not remove directory: $Path"
    }
}

function Install-WindowsLibsodiumIfNeeded {
    param(
        [switch]$ForceRefresh
    )

    $libsDir = Join-Path $repoRoot "libsodium"
    
    # Check if libsodium directory exists and has the required DLLs
    if ((-not $ForceRefresh) -and (Test-Path $libsDir)) {
        $arch = $env:PROCESSOR_ARCHITECTURE
        $requiredDll = if ($arch -eq "AMD64") {
            Join-Path $libsDir "libsodium-26.x64.dll"
        } else {
            Join-Path $libsDir "libsodium-26.x32.dll"
        }
        
        if (Test-Path $requiredDll) {
            Write-Host "[demo-day] libsodium already present"
            return $true
        }
    }
    
    # Need to download libsodium
    if ($ForceRefresh) {
        Write-Host "[demo-day] refreshing bundled libsodium binaries..."
    } else {
        Write-Host "[demo-day] libsodium not found; downloading..."
    }
    
    try {
        $tempZip = Join-Path $repoRoot "libsodium_download.zip"
        $tempDir = Join-Path $repoRoot "libsodium_temp"
        
        # Download libsodium release
        $url = "https://github.com/jedisct1/libsodium/releases/download/1.0.19-RELEASE/libsodium-1.0.19-msvc.zip"
        Write-Host "[demo-day] Downloading from $url"
        Invoke-WebRequest -Uri $url -OutFile $tempZip -UseBasicParsing
        
        # Extract
        if (Test-Path $tempDir) {
            Remove-Item -Recurse -Force $tempDir
        }
        Expand-Archive -Path $tempZip -DestinationPath $tempDir -Force
        
        # Recreate libsodium directory on forced refresh
        if ($ForceRefresh -and (Test-Path $libsDir)) {
            Remove-Item -Recurse -Force $libsDir
        }
        if (-not (Test-Path $libsDir)) {
            New-Item -ItemType Directory -Force -Path $libsDir | Out-Null
        }
        
        # Copy the appropriate DLLs based on architecture
        $arch = $env:PROCESSOR_ARCHITECTURE
        if ($arch -eq "AMD64") {
            $x64Dll = Join-Path $tempDir "libsodium\x64\Release\v143\dynamic\libsodium.dll"
            $x86Dll = Join-Path $tempDir "libsodium\Win32\Release\v143\dynamic\libsodium.dll"
        } else {
            $x86Dll = Join-Path $tempDir "libsodium\Win32\Release\v143\dynamic\libsodium.dll"
            $x64Dll = Join-Path $tempDir "libsodium\x64\Release\v143\dynamic\libsodium.dll"
        }
        
        if (Test-Path $x64Dll) {
            Copy-Item -Path $x64Dll -Destination (Join-Path $libsDir "libsodium-26.x64.dll") -Force
        }
        if (Test-Path $x86Dll) {
            Copy-Item -Path $x86Dll -Destination (Join-Path $libsDir "libsodium-26.x32.dll") -Force
        }
        
        # Cleanup
        Remove-Item -Recurse -Force $tempDir
        Remove-Item -Force $tempZip
        
        Write-Host "[demo-day] libsodium downloaded and installed"
        return $true
    }
    catch {
        Write-Host "[demo-day] WARNING: failed to auto-download libsodium: $_"
        return $false
    }
}

function Initialize-WindowsLibsodium {
    $libsDir = Join-Path $repoRoot "libsodium"
    if (-not (Test-Path $libsDir)) {
        # Try to auto-install libsodium
        if (-not (Install-WindowsLibsodiumIfNeeded)) {
            Write-Host "[demo-day] WARNING: libsodium not available - some tests may fail"
            return
        }
    }

    $arch = $env:PROCESSOR_ARCHITECTURE
    $candidates = if ($arch -eq "AMD64") {
        @(
            (Join-Path $libsDir "libsodium-26.x64.dll"),
            (Join-Path $libsDir "libsodium-26.x32.dll")
        )
    }
    else {
        @(
            (Join-Path $libsDir "libsodium-26.x32.dll"),
            (Join-Path $libsDir "libsodium-26.x64.dll")
        )
    }

    $sourceDll = $null
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            $sourceDll = $candidate
            break
        }
    }

    if ($null -eq $sourceDll) {
        Write-Host "[demo-day] WARNING: no bundled libsodium DLL found in $libsDir - some tests may fail"
        return
    }

    $targetDll = Join-Path $libsDir "libsodium.dll"
    
    # Check if target already exists and is the same size - skip copy if so
    $skipCopy = $false
    if (Test-Path $targetDll) {
        $sourceSize = (Get-Item $sourceDll).Length
        $targetSize = (Get-Item $targetDll).Length
        if ($sourceSize -eq $targetSize) {
            $skipCopy = $true
            Write-Host "[demo-day] libsodium. DLL already up to date, skipping copy"
        }
    }
    
    if (-not $skipCopy) {
        try {
            Copy-Item -Path $sourceDll -Destination $targetDll -Force -ErrorAction Stop
        } catch {
            Write-Host "[demo-day] WARNING: could not copy libsodium DLL (may be in use by another process) - continuing anyway"
        }
    }

    if (Test-Path $targetDll) {
        $env:Path = "$libsDir;$env:Path"
    }
}

function Test-WindowsLibsodiumLoad {
    param(
        [string]$PythonExe,
        [string]$LibsDir
    )

    $candidates = @(
        (Join-Path $LibsDir "libsodium.dll"),
        (Join-Path $LibsDir "libsodium-26.x64.dll"),
        (Join-Path $LibsDir "libsodium-26.x32.dll")
    )

    foreach ($candidate in $candidates) {
        if (-not (Test-Path $candidate)) {
            continue
        }

        $oldNativeErrPref = $null
        $hadNativeErrPref = $false
        if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -Scope Global -ErrorAction SilentlyContinue) {
            $hadNativeErrPref = $true
            $oldNativeErrPref = $Global:PSNativeCommandUseErrorActionPreference
        }

        $canLoadCandidate = $false
        try {
            $Global:PSNativeCommandUseErrorActionPreference = $false
            try {
                & $PythonExe -c "import ctypes, sys; ctypes.WinDLL(sys.argv[1])" "$candidate" *> $null
                $canLoadCandidate = ($LASTEXITCODE -eq 0)
            }
            catch {
                $canLoadCandidate = $false
            }
        }
        finally {
            if ($hadNativeErrPref) {
                $Global:PSNativeCommandUseErrorActionPreference = $oldNativeErrPref
            }
            else {
                Remove-Variable -Name PSNativeCommandUseErrorActionPreference -Scope Global -ErrorAction SilentlyContinue
            }
        }

        if ($canLoadCandidate) {
            $targetDll = Join-Path $LibsDir "libsodium.dll"
            if ($candidate -ne $targetDll) {
                try { Copy-Item -Path $candidate -Destination $targetDll -Force -ErrorAction Stop } catch { Write-Host "[demo-day] WARNING: could not copy libsodium DLL (may be in use) - continuing anyway" }
            }
            return $true
        }
    }

    return $false
}

function Install-UvIfNeeded {
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        return $true
    }

    if (-not $autoInstallUv) {
        return $false
    }

    Write-Host "[demo-day] uv not found; attempting automatic install"
    try {
        powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex" | Out-Null
    }
    catch {
        Write-Host "[demo-day] ERROR: failed to auto-install uv"
        return $false
    }

    if (Get-Command uv -ErrorAction SilentlyContinue) {
        return $true
    }

    $userUv = Join-Path $env:USERPROFILE ".local\bin\uv.exe"
    if (Test-Path $userUv) {
        $env:Path = "$(Split-Path $userUv);$env:Path"
    }

    return [bool](Get-Command uv -ErrorAction SilentlyContinue)
}

function Invoke-Python {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$PyArgs
    )

    if ($script:UsingUvPython) {
        & uv @("run", "--python", "3.13", "python") @PyArgs
    }
    else {
        & $script:PythonCmd @script:PythonBaseArgs @PyArgs
    }

    if ($LASTEXITCODE -ne 0) {
        throw "Python command failed: $($PyArgs -join ' ')"
    }
}

# Interpreter selection (PySide6 6.9.x is incompatible with Python 3.14).
$script:UsingUvPython = $false
$script:PythonCmd = ""
$script:PythonBaseArgs = @()
if ([string]::IsNullOrWhiteSpace($PythonBin)) {
    foreach ($candidate in @("python3.13")) {
        if (Get-Command $candidate -ErrorAction SilentlyContinue) {
            $PythonBin = $candidate
            break
        }
    }

    # Windows python.org installs `python` on PATH, not `python3.13`.
    if ([string]::IsNullOrWhiteSpace($PythonBin) -and ($env:OS -match "Windows")) {
        if (Get-Command python -ErrorAction SilentlyContinue) {
            try {
                $probe = (& python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')").Trim()
                if ($probe -eq "3.13") {
                    $PythonBin = "python"
                }
            }
            catch {
                # Keep searching/provisioning below.
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($PythonBin) -and (Get-Command py -ErrorAction SilentlyContinue)) {
        try {
            $probe = ((& py -3.13 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null)).Trim()
            if ($probe -eq "3.13") {
                $PythonBin = "py"
                $script:PythonBaseArgs = @("-3.13")
            }
        }
        catch {
            # Keep searching/provisioning below.
        }
    }
}

if ([string]::IsNullOrWhiteSpace($PythonBin)) {
    if (Install-UvIfNeeded) {
        Write-Host "[demo-day] provisioning Python 3.13 via uv"
        & uv python install 3.13 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install Python 3.13 via uv"
        }
        $script:UsingUvPython = $true
        $PythonBin = "uv-python-3.13"
    }
}

if ([string]::IsNullOrWhiteSpace($PythonBin)) {
    throw "[demo-day] ERROR: no usable Python found. Install Python 3.13 or install uv."
}

if (-not $script:UsingUvPython) {
    $resolved = $false
    if (Get-Command $PythonBin -ErrorAction SilentlyContinue) {
        $script:PythonCmd = $PythonBin
        # Auto-discovery may have set BaseArgs (e.g. `py -3.13`); do not clear them.
        if ($script:PythonBaseArgs.Count -eq 0) {
            $script:PythonBaseArgs = @()
        }
        $resolved = $true
    }
    elseif (($PythonBin -eq "python3.13") -and ($env:OS -match "Windows")) {
        # README uses `python3.13` like Unix; on Windows use `python` or `py -3.13`.
        if (Get-Command python -ErrorAction SilentlyContinue) {
            try {
                $probe = (& python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')").Trim()
                if ($probe -eq "3.13") {
                    $script:PythonCmd = "python"
                    $script:PythonBaseArgs = @()
                    $resolved = $true
                }
            }
            catch {
                # Try `py` below.
            }
        }
        if (-not $resolved -and (Get-Command py -ErrorAction SilentlyContinue)) {
            try {
                $probe = ((& py -3.13 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null)).Trim()
                if ($probe -eq "3.13") {
                    $script:PythonCmd = "py"
                    $script:PythonBaseArgs = @("-3.13")
                    $resolved = $true
                }
            }
            catch {
                # Fall through to error.
            }
        }
    }
    if (-not $resolved) {
        throw "[demo-day] ERROR: PythonBin '$PythonBin' is not executable on PATH."
    }
}

$pyVer = if ($script:UsingUvPython) {
    (& uv run --python 3.13 python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')").Trim()
} else {
    (& $script:PythonCmd @script:PythonBaseArgs -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')").Trim()
}

if ($pyVer -ne "3.13") {
    throw "[demo-day] ERROR: Python $pyVer detected. This demo requires Python 3.13 (PySide6 6.9.x compatibility)."
}

$interpLabel = if ($script:UsingUvPython) {
    "uv (Python 3.13)"
}
elseif ($script:PythonBaseArgs.Count -gt 0) {
    "$($script:PythonCmd) $($script:PythonBaseArgs -join ' ')"
}
else {
    $script:PythonCmd
}
Write-Host "[demo-day] using $interpLabel ($pyVer)"
Set-Location $repoRoot
Write-Host "[demo-day] using LOCKSMITH_BASE=$locksmithBase"

if ($ResetDemoState) {
    Write-Host "[demo-day] clearing demo state for base '$locksmithBase'"
    $roots = Get-DemoStateRoots -RepoRoot $repoRoot
    if ($roots.Count -eq 0) {
        Write-Host "[demo-day] no existing demo state roots found"
    }
    else {
        Write-Host "[demo-day] reset roots: $($roots -join ', ')"
    }

    # KERI stores keyed by LOCKSMITH_BASE.
    $stores = @("db", "ks", "cf", "rt", "reg", "mbx", "not", "locksmith")

    $removedTargets = New-Object System.Collections.Generic.List[string]
    $missingTargets = New-Object System.Collections.Generic.List[string]
    $failedTargets = New-Object System.Collections.Generic.List[string]

    foreach ($root in $roots) {
        foreach ($store in $stores) {
            $target = Join-Path $root (Join-Path $store $locksmithBase)
            if (Test-Path $target) {
                try {
                    Remove-Item -Recurse -Force $target -ErrorAction Stop
                    $removedTargets.Add($target)
                    Write-Host "[demo-day] removed $target"
                }
                catch {
                    $failedTargets.Add($target)
                    Write-Host "[demo-day] WARNING: failed to remove $target"
                }
            }
            else {
                $missingTargets.Add($target)
            }
        }
    }

    Write-Host "[demo-day] reset summary: removed=$($removedTargets.Count) missing=$($missingTargets.Count) failed=$($failedTargets.Count)"
    if ($failedTargets.Count -gt 0) {
        Write-Host "[demo-day] WARNING: reset completed with failed removals. Ensure LockSmith is fully closed and retry."
    }
}

Initialize-WindowsLibsodium

$venvDir = Join-Path $repoRoot ".venv"
$venvPython = Join-Path $venvDir "Scripts\python.exe"
$venvPytest = Join-Path $venvDir "Scripts\pytest.exe"
$venvRcc = Join-Path $venvDir "Scripts\pyside6-rcc.exe"

# Preflight: always drop an existing .venv so Windows setup is not fighting a Linux/WSL or broken tree (UNC-safe removal).
if ($SetupOnly -and (Test-Path -LiteralPath $venvDir)) {
    Write-Host "[demo-day] SetupOnly: removing existing .venv for a clean preflight..."
    Remove-DemoDayDirectoryWithHeartbeat -Path $venvDir -Label "virtual environment cleanup"
}

if (-not (Test-Path $venvDir)) {
    Write-Host "[demo-day] creating virtual environment"
    Invoke-Python -m venv $venvDir
}
elseif (-not (Test-Path $venvPython)) {
    # Same repo on a UNC path or a WSL/Linux-created venv has bin/python but not Scripts\python.exe.
    $linuxVenvPython = Join-Path $venvDir "bin\python"
    if (Test-Path $linuxVenvPython) {
        Write-Host "[demo-day] existing .venv is not usable on Windows (e.g. created under Linux/WSL); recreating for Windows..."
    }
    else {
        Write-Host "[demo-day] existing .venv is missing Scripts\python.exe; recreating virtual environment..."
    }
    Remove-DemoDayDirectoryWithHeartbeat -Path $venvDir -Label "virtual environment cleanup"
    Invoke-Python -m venv $venvDir
}

if (-not (Test-Path $venvPython)) {
    throw "[demo-day] ERROR: virtualenv python not found at $venvPython"
}

$venvVer = (& $venvPython -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')").Trim()
if ($venvVer -ne "3.13") {
    Write-Host "[demo-day] existing .venv is Python $venvVer; recreating with Python 3.13"
    Remove-DemoDayDirectoryWithHeartbeat -Path $venvDir -Label "virtual environment cleanup"
    Invoke-Python -m venv $venvDir
}

$basePythonDir = (& $venvPython -c "import sys; print(sys.base_prefix)").Trim()
if (-not [string]::IsNullOrWhiteSpace($basePythonDir)) {
    $basePythonDllDir = Join-Path $basePythonDir "DLLs"
    $env:Path = "$basePythonDir;$basePythonDllDir;$env:Path"
}

$libsDir = Join-Path $repoRoot "libsodium"

# Check if libsodium directory exists and has required DLLs
$libsodiumAvailable = $false
if (-not (Test-Path $libsDir)) {
    Write-Host "[demo-day] libsodium directory not found; attempting auto-download..."
    $libsodiumAvailable = Install-WindowsLibsodiumIfNeeded
} else {
    # Directory exists, check if it has the required DLLs
    $arch = $env:PROCESSOR_ARCHITECTURE
    $requiredDll = if ($arch -eq "AMD64") {
        Join-Path $libsDir "libsodium-26.x64.dll"
    } else {
        Join-Path $libsDir "libsodium-26.x32.dll"
    }
    
    if (-not (Test-Path $requiredDll)) {
        Write-Host "[demo-day] libsodium DLLs not found; attempting auto-download..."
        $libsodiumAvailable = Install-WindowsLibsodiumIfNeeded
    } else {
        $libsodiumAvailable = $true
    }
}

# Test if libsodium can be loaded
$libsodiumLoaded = $false
if ($libsodiumAvailable) {
    $libsodiumLoaded = Test-WindowsLibsodiumLoad -PythonExe $venvPython -LibsDir $libsDir
}

if ($libsodiumLoaded) {
    Write-Host "[demo-day] libsodium loaded successfully"
} else {
    # One self-heal attempt: refresh DLL bundle and probe again.
    if (Install-WindowsLibsodiumIfNeeded -ForceRefresh) {
        Initialize-WindowsLibsodium
        $libsodiumLoaded = Test-WindowsLibsodiumLoad -PythonExe $venvPython -LibsDir $libsDir
    }

    if ($libsodiumLoaded) {
        Write-Host "[demo-day] libsodium loaded successfully after refresh"
    } else {
        Write-Host "[demo-day] WARNING: unable to load libsodium - some tests may fail"
        Write-Host "[demo-day] To fix: Install Microsoft Visual C++ Redistributable (x64) or ensure libsodium DLLs are in $libsDir"
    }
}

Write-Host "[demo-day] installing dependencies (editable + dev extras)"
$pipReady = $false
try {
    & $venvPython -m pip --version > $null 2>&1
    $pipReady = ($LASTEXITCODE -eq 0)
}
catch {
    $pipReady = $false
}

if (-not $pipReady) {
    Write-Host "[demo-day] pip missing in .venv; bootstrapping with ensurepip"
    & $venvPython -m ensurepip --upgrade
    if ($LASTEXITCODE -ne 0) {
        throw "ensurepip failed; unable to bootstrap pip in .venv"
    }

    try {
        & $venvPython -m pip --version > $null 2>&1
        $pipReady = ($LASTEXITCODE -eq 0)
    }
    catch {
        $pipReady = $false
    }

    if (-not $pipReady) {
        throw "pip bootstrap completed but python -m pip is still unavailable in .venv"
    }
}

Write-Host "[demo-day] upgrading pip"
Invoke-ExternalCommandWithHeartbeat -Label "pip upgrade" -FilePath $venvPython -ArgumentList @("-m", "pip", "install", "--upgrade", "pip", "--quiet")
Write-Host "[demo-day] installing project dependencies"
Invoke-ExternalCommandWithHeartbeat -Label "dependency install" -FilePath $venvPython -ArgumentList @("-m", "pip", "install", "-e", ".[dev]", "--quiet")

Write-Host "[demo-day] refreshing Qt resources"
Write-Host "[demo-day] generating resources.qrc"
Invoke-ExternalCommandWithHeartbeat -Label "resource manifest generation" -FilePath $venvPython -ArgumentList @(".\scripts\generate_qrc.py")
Write-Host "[demo-day] compiling Qt resource module"
Invoke-ExternalCommandWithHeartbeat -Label "Qt resource compilation" -FilePath $venvRcc -ArgumentList @("resources.qrc", "-o", "resources_rc.py")
Move-Item -Force "resources_rc.py" ".\src\locksmith\resources_rc.py"

Write-Host "[demo-day] running smoke tests"
$previousQtPlatform = $env:QT_QPA_PLATFORM
$hadQtPlatform = Test-Path Env:QT_QPA_PLATFORM

try {
    $env:QT_QPA_PLATFORM = "offscreen"
    & $venvPytest "tests/" "-v" "--tb=short"
    if ($LASTEXITCODE -ne 0) { throw "smoke tests failed" }
}
finally {
    if ($hadQtPlatform) {
        $env:QT_QPA_PLATFORM = $previousQtPlatform
    }
    else {
        Remove-Item Env:QT_QPA_PLATFORM -ErrorAction SilentlyContinue
    }
}

if ($SetupOnly) {
    Write-Host "[demo-day] preflight complete (SetupOnly) - ready to demo"
    exit 0
}

Write-Host "[demo-day] launching LockSmith"
& $venvPython ".\src\locksmith\main.py"

