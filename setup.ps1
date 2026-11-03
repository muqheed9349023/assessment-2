param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot

$uvCommand = Get-Command uv -ErrorAction SilentlyContinue
if (-not $uvCommand) {
    throw 'uv is required. Install it from https://docs.astral.sh/uv/getting-started/installation/ and run .\setup.ps1 again.'
}

$venvPython = Join-Path $repoRoot '.venv\Scripts\python.exe'
if (-not (Test-Path $venvPython)) {
    $python310 = $null

    # Prefer a Python 3.10 interpreter already installed on this computer.
    $pyLauncher = Get-Command py -ErrorAction SilentlyContinue
    if ($pyLauncher) {
        $candidate = & py -3.10 -c 'import sys; print(sys.executable)' 2>$null
        if ($LASTEXITCODE -eq 0 -and $candidate) { $python310 = $candidate.Trim() }
    }

    if (-not $python310) {
        $candidate = & uv python find 3.10 --managed-python 2>$null
        if ($LASTEXITCODE -eq 0 -and $candidate) { $python310 = $candidate.Trim() }
    }

    if (-not $python310) {
        Write-Host 'Installing Python 3.10 with uv...'
        & uv python install --native-tls 3.10
        if ($LASTEXITCODE -ne 0) { throw 'Could not install Python 3.10. Install Python 3.10 manually, then rerun setup.' }
        $candidate = & uv python find 3.10 --managed-python
        if ($LASTEXITCODE -ne 0 -or -not $candidate) { throw 'uv installed Python but could not locate it.' }
        $python310 = $candidate.Trim()
    }

    & uv venv --python $python310 (Join-Path $repoRoot '.venv')
    if ($LASTEXITCODE -ne 0) { throw 'Could not create the project virtual environment.' }
}

Write-Host 'Installing the small Windows runtime (no CUDA packages)...'
& uv pip install --native-tls --python $venvPython -r (Join-Path $repoRoot 'requirements-quickstart.txt')
if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed.' }

if (-not (Test-Path (Join-Path $repoRoot '.env'))) {
    Copy-Item (Join-Path $repoRoot '.env.example') (Join-Path $repoRoot '.env')
    Write-Host 'Created .env from .env.example. Add your API keys there for live model calls.'
}

Write-Host ''
Write-Host 'Setup complete. Run the free local demo with: .\run.ps1'
