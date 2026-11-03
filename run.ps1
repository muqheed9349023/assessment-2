param(
    [ValidateSet('demo', 'generate', 'evaluate')]
    [string]$Mode = 'demo',
    [ValidateRange(1, 2280)]
    [int]$Examples = 1,
    [string]$ResultPath = ''
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot

$venvPython = Join-Path $repoRoot '.venv\Scripts\python.exe'
if (-not (Test-Path $venvPython)) {
    & (Join-Path $repoRoot 'setup.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Setup did not complete.' }
}

# Load simple KEY=VALUE lines from the ignored local .env file.
$envFile = Join-Path $repoRoot '.env'
if (Test-Path $envFile) {
    foreach ($line in Get-Content $envFile) {
        if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$') {
            $name = $Matches[1]
            $value = $Matches[2]
            if ($value.Length -ge 2 -and (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'")))) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            [Environment]::SetEnvironmentVariable($name, $value, 'Process')
        }
    }
}

$env:LONGFACT_MAX_NUM_EXAMPLES = [string]$Examples

switch ($Mode) {
    'demo' {
        $env:LONGFACT_DEMO = '1'
        Write-Host "Running the local no-API demo on $Examples prompt(s)..."
        & $venvPython -m main.pipeline
    }
    'generate' {
        if (-not $env:OPENAI_API_KEY -and -not $env:ANTHROPIC_API_KEY) {
            throw 'Add OPENAI_API_KEY or ANTHROPIC_API_KEY to .env before live generation.'
        }
        Remove-Item Env:LONGFACT_DEMO -ErrorAction SilentlyContinue
        Write-Host "Generating responses for $Examples prompt(s). API usage may incur charges."
        & $venvPython -m main.pipeline
    }
    'evaluate' {
        if (-not $ResultPath) { throw 'Pass -ResultPath with the JSON produced by generation.' }
        if (-not $env:OPENAI_API_KEY) { throw 'SAFE evaluation requires OPENAI_API_KEY in .env.' }
        if (-not $env:SERPER_API_KEY) { throw 'SAFE evaluation requires SERPER_API_KEY in .env.' }
        Remove-Item Env:LONGFACT_DEMO -ErrorAction SilentlyContinue
        Write-Host 'Installing SAFE evaluation dependencies (CPU-only)...'
        & uv pip install --native-tls --python $venvPython -r (Join-Path $repoRoot 'requirements-safe.txt')
        if ($LASTEXITCODE -ne 0) { throw 'SAFE dependency installation failed.' }
        $resolvedResult = (Resolve-Path $ResultPath).Path
        Write-Host 'SAFE uses language-model and search API calls; usage may incur charges.'
        & $venvPython -m eval.run_eval "--result_path=$resolvedResult"
    }
}

if ($LASTEXITCODE -ne 0) { throw "LongFact command failed with exit code $LASTEXITCODE." }
