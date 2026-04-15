Param(
    [string]$PythonBin = "",
    [switch]$SetupOnly,
    [switch]$NoAutoInstallUv
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$autoInstallUv = -not $NoAutoInstallUv

function Install-WindowsLibsodiumIfNeeded {
    $libsDir = Join-Path $repoRoot "libsodium"
    
    # Check if libsodium directory exists and has the required DLLs
    if (Test-Path $libsDir) {
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
    Write-Host "[demo-day] libsodium not found; downloading..."
    
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
        
        # Create libsodium directory if it doesn't exist
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

function Ensure-WindowsLibsodium {
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

        try {
            $Global:PSNativeCommandUseErrorActionPreference = $false
            & $PythonExe -c "import ctypes, sys; ctypes.WinDLL(sys.argv[1])" "$candidate" > $null 2>&1
        }
        finally {
            if ($hadNativeErrPref) {
                $Global:PSNativeCommandUseErrorActionPreference = $oldNativeErrPref
            }
            else {
                Remove-Variable -Name PSNativeCommandUseErrorActionPreference -Scope Global -ErrorAction SilentlyContinue
            }
        }

        if ($LASTEXITCODE -eq 0) {
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

    if ([string]::IsNullOrWhiteSpace($PythonBin) -and (Get-Command py -ErrorAction SilentlyContinue)) {
        try {
            $probe = (& py -3.13 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')").Trim()
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

if (-not $script:UsingUvPython -and -not (Get-Command $PythonBin -ErrorAction SilentlyContinue)) {
    throw "[demo-day] ERROR: PythonBin '$PythonBin' is not executable on PATH."
}

$script:PythonCmd = $PythonBin

$pyVer = if ($script:UsingUvPython) {
    (& uv run --python 3.13 python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')").Trim()
} else {
    (& $script:PythonCmd @script:PythonBaseArgs -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')").Trim()
}

if ($pyVer -ne "3.13") {
    throw "[demo-day] ERROR: Python $pyVer detected. This demo requires Python 3.13 (PySide6 6.9.x compatibility)."
}

Write-Host "[demo-day] using $PythonBin ($pyVer)"
Set-Location $repoRoot
Ensure-WindowsLibsodium

if (-not (Test-Path ".venv")) {
    Write-Host "[demo-day] creating virtual environment"
    Invoke-Python -m venv .venv
}

$venvPython = ".venv\Scripts\python.exe"
$venvPytest = ".venv\Scripts\pytest.exe"
$venvRcc = ".venv\Scripts\pyside6-rcc.exe"

if (-not (Test-Path $venvPython)) {
    throw "[demo-day] ERROR: virtualenv python not found at $venvPython"
}

$venvVer = (& $venvPython -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')").Trim()
if ($venvVer -ne "3.13") {
    Write-Host "[demo-day] existing .venv is Python $venvVer; recreating with Python 3.13"
    Remove-Item -Recurse -Force .venv
    Invoke-Python -m venv .venv
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
if ($libsodiumAvailable -and (Test-WindowsLibsodiumLoad -PythonExe $venvPython -LibsDir $libsDir)) {
    Write-Host "[demo-day] libsodium loaded successfully"
} else {
    Write-Host "[demo-day] WARNING: unable to load libsodium - some tests may fail"
    Write-Host "[demo-day] To fix: Install Microsoft Visual C++ Redistributable (x64) or ensure libsodium DLLs are in $libsDir"
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

& $venvPython -m pip install --upgrade pip --quiet
if ($LASTEXITCODE -ne 0) { throw "pip upgrade failed" }
& $venvPython -m pip install -e ".[dev]" --quiet
if ($LASTEXITCODE -ne 0) { throw "dependency install failed" }

Write-Host "[demo-day] refreshing Qt resources"
& $venvPython ".\scripts\generate_qrc.py"
if ($LASTEXITCODE -ne 0) { throw "generate_qrc.py failed" }
& $venvRcc "resources.qrc" "-o" "resources_rc.py"
if ($LASTEXITCODE -ne 0) { throw "pyside6-rcc failed" }
Move-Item -Force "resources_rc.py" ".\src\locksmith\resources_rc.py"

Write-Host "[demo-day] running smoke tests"
$env:QT_QPA_PLATFORM = "offscreen"
& $venvPytest "tests/" "-v" "--tb=short"
if ($LASTEXITCODE -ne 0) { throw "smoke tests failed" }

if ($SetupOnly) {
    Write-Host "[demo-day] preflight complete (SetupOnly) - ready to demo"
    exit 0
}

Write-Host "[demo-day] launching LockSmith"
& $venvPython ".\src\locksmith\main.py"

