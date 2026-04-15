Param(
    [string]$PythonBin = "",
    [switch]$SetupOnly,
    [switch]$NoAutoInstallUv
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$autoInstallUv = -not $NoAutoInstallUv

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

Write-Host "[demo-day] installing dependencies (editable + dev extras)"
$pipExe = ".venv\Scripts\pip.exe"
$pipReady = Test-Path $pipExe

if ($pipReady) {
    try {
        & $venvPython -m pip --version > $null 2>&1
        $pipReady = ($LASTEXITCODE -eq 0)
    }
    catch {
        $pipReady = $false
    }
}

if (-not $pipReady) {
    Write-Host "[demo-day] pip missing in .venv; bootstrapping with ensurepip"
    & $venvPython -m ensurepip --upgrade
    if ($LASTEXITCODE -ne 0) {
        throw "ensurepip failed; unable to bootstrap pip in .venv"
    }

    if (-not (Test-Path $pipExe)) {
        throw "pip bootstrap completed but pip.exe is still missing in .venv"
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
