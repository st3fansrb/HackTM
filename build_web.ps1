# Build Frigo PWA with API keys from .env
# Usage: .\build_web.ps1
# After build: firebase deploy --only hosting

Get-Content .env | ForEach-Object {
    if ($_ -match '^([^#][^=]*)=(.*)$') {
        [System.Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim())
    }
}

Write-Host "Building Frigo web..." -ForegroundColor Cyan

flutter build web `
    --dart-define=GROQ_API_KEY=$env:GROQ_API_KEY `
    --dart-define=GEMINI_API_KEY=$env:GEMINI_API_KEY `
    --release

if ($LASTEXITCODE -eq 0) {
    Write-Host "Build OK. Deploy cu: firebase deploy --only hosting" -ForegroundColor Green
} else {
    Write-Host "Build FAILED." -ForegroundColor Red
    exit 1
}
