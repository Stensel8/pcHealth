# ============================================================================
# pcHealth — Windows 11 — GUI launcher
# Builds the WinUI 3 project in Release mode, then starts the application.
# The EXE requests administrator privileges via its own app.manifest, so no
# elevation is needed here.
# ============================================================================

$ErrorActionPreference = 'Stop'

$projectFile = Join-Path $PSScriptRoot 'pcHealth\pcHealth.csproj'
$exePath     = Join-Path $PSScriptRoot 'pcHealth\bin\Release\net10.0-windows10.0.19041.0\win-x64\pcHealth.exe'

Write-Host 'Building pcHealth GUI...' -ForegroundColor Cyan
dotnet build $projectFile -c Release --nologo -v minimal

if ($LASTEXITCODE -ne 0) {
    Write-Host 'Build failed. See output above for details.' -ForegroundColor Red
    Read-Host "`nPress Enter to exit"
    exit 1
}

Write-Host 'Build succeeded. Launching pcHealth...' -ForegroundColor Green
Start-Process -FilePath $exePath
