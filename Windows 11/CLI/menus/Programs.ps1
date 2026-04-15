# ============================================================================
# pcHealth — Windows 11 — Programs Menu
# ============================================================================

# Translates a winget exit code into a human-readable message and a flag that
# indicates whether the error suggests winget itself is broken.
# Source: https://github.com/microsoft/winget-cli/blob/master/doc/windows/package-manager/winget/returnCodes.md
function Get-WingetResult {
    param([int]$ExitCode)

    # Convert signed int32 to the 0x8A15xxxx hex string winget uses.
    # Reinterpret the raw bytes of the signed int32 as uint32 — avoids cast
    # errors that occur with negative values like -1 or -1978335189.
    $hex = '0x{0:X8}' -f ([System.BitConverter]::ToUInt32([System.BitConverter]::GetBytes([int32]$ExitCode), 0))

    # --- Informational: normal outcomes, winget is working fine ---
    $info = @{
        '0x8A15002B' = 'No applicable update found (already up to date).'
        '0x8A15004F' = 'A newer or equal version is already installed.'
        '0x8A150050' = 'Upgrade version is unknown.'
        '0x8A150061' = 'Package is already installed.'
        '0x8A150068' = 'Package is pinned and cannot be upgraded.'
        '0x8A150101' = 'Application is currently running. Close it and try again.'
        '0x8A150102' = 'Another installation is already in progress. Try again later.'
        '0x8A150103' = 'A file is in use. Close the application and try again.'
        '0x8A150104' = 'A required dependency is missing.'
        '0x8A150105' = 'Not enough disk space. Free up space and try again.'
        '0x8A150106' = 'Not enough memory available. Close other applications and try again.'
        '0x8A150107' = 'No internet connection. Connect to a network and try again.'
        '0x8A150109' = 'Restart your PC to finish installation.'
        '0x8A15010A' = 'Restart your PC and try again.'
        '0x8A15010B' = 'Your PC will restart to finish installation.'
        '0x8A15010C' = 'Installation cancelled.'
        '0x8A15010D' = 'Another version of this application is already installed.'
        '0x8A15010E' = 'A higher version is already installed.'
        '0x8A15010F' = 'Installation is blocked by organisation policy. Contact your admin.'
        '0x8A150056' = 'This installer cannot run from an administrator context.'
        '0x8A150114' = 'The installer does not support upgrading an existing package.'
    }

    # --- Broken: errors that suggest winget itself needs repair ---
    $broken = @{
        '0x8A150001' = 'Internal error.'
        '0x8A150003' = 'Executing command failed.'
        '0x8A150008' = 'Download failed.'
        '0x8A15000A' = 'The package index is corrupt.'
        '0x8A15000B' = 'The configured source information is corrupt.'
        '0x8A15000F' = 'Data required by the source is missing.'
        '0x8A150011' = 'Installer hash mismatch — the download may be corrupt.'
        '0x8A150014' = 'No packages found. The source may be unavailable.'
        '0x8A150015' = 'No sources are configured.'
        '0x8A150037' = 'Source configuration error.'
        '0x8A150038' = 'The configured source is not supported.'
        '0x8A150039' = 'Invalid data returned by source.'
        '0x8A15003F' = 'The source data is corrupted or tampered.'
        '0x8A150045' = 'Failed to open the source.'
        '0x8A15004B' = 'Failed to open one or more sources.'
        '0x8A150086' = 'Downloaded a zero-byte installer. Check your network connection.'
    }

    if ($ExitCode -eq 0) {
        return @{ Ok = $true; Message = 'Successfully installed.'; SuggestRepair = $false }
    }
    if ($info.ContainsKey($hex)) {
        return @{ Ok = $false; Message = $info[$hex]; SuggestRepair = $false }
    }
    if ($broken.ContainsKey($hex)) {
        return @{ Ok = $false; Message = $broken[$hex]; SuggestRepair = $true }
    }

    # Unknown code — show hex so the user can look it up, and suggest repair.
    return @{ Ok = $false; Message = "Unexpected exit code ($hex)."; SuggestRepair = $true }
}

function Show-ProgramsMenu {
    # Maps menu key → package display name + winget ID.
    $packages = @{
        '1' = @{ Name = 'HWiNFO64';                 Id = 'REALix.HWiNFO'                      }
        '2' = @{ Name = 'HWMonitor';                Id = 'CPUID.HWMonitor'                     }
        '3' = @{ Name = 'Malwarebytes ADW Cleaner'; Id = 'Malwarebytes.AdwCleaner'             }
        '4' = @{ Name = 'CrystalDiskInfo';          Id = 'CrystalDewWorld.CrystalDiskInfo'     }
        '5' = @{ Name = 'CrystalDiskMark';          Id = 'CrystalDewWorld.CrystalDiskMark'     }
        '6' = @{ Name = 'Prime95';                  Id = 'mersenne.prime95'                    }
        '7' = @{ Name = 'Windows PowerToys';        Id = 'Microsoft.PowerToys'                 }
    }

    while ($true) {
        Set-PcTheme 'Programs'
        Clear-Host
        Write-PcHeader 'Programs'

        Write-PcOption '1' 'HWiNFO64'
        Write-PcOption '2' 'HWMonitor'
        Write-PcOption '3' 'Malwarebytes ADW Cleaner'
        Write-PcOption '4' 'CrystalDiskInfo'
        Write-PcOption '5' 'CrystalDiskMark'
        Write-PcOption '6' 'Prime95'
        Write-PcOption '7' 'Windows PowerToys'
        Write-PcDivider
        Write-PcOption '8'  'Tools Menu'
        Write-PcOption '9'  'Back to Main Menu'
        Write-PcOption '10' 'Exit'
        Write-PcDivider

        $choice = (Read-Host "`n  Choice").Trim()

        # Navigation choices — return immediately.
        switch ($choice) {
            '8'  { return 'tools' }
            '9'  { return 'main'  }
            '10' { return 'exit'  }
        }

        # Install choices.
        if ($packages.ContainsKey($choice)) {
            $pkg = $packages[$choice]
            Set-PcTheme 'Action'
            Clear-Host
            Write-Host "[>>] Installing $($pkg.Name)...`n" -ForegroundColor Yellow

            # winget is an MSIX app and fails silently when called inline in an
            # elevated session. Spawning it via Start-Process mirrors what the
            # GUI does (UseShellExecute) and resolves it correctly.
            $proc = Start-Process winget `
                -ArgumentList "install --id $($pkg.Id) --accept-source-agreements --accept-package-agreements" `
                -Wait -PassThru -NoNewWindow

            $result = Get-WingetResult $proc.ExitCode
            if ($result.Ok) {
                Write-Host "`n[OK] $($pkg.Name) installed." -ForegroundColor Green
            } else {
                $color = if ($result.SuggestRepair) { 'Red' } else { 'Yellow' }
                Write-Host "`n[!!] $($result.Message)" -ForegroundColor $color
                if ($result.SuggestRepair) {
                    Write-Host "     Tip: try 'Repair Winget' in the Tools menu (option 22)." -ForegroundColor DarkGray
                }
            }

            $nav = Read-PcNavChoice 'Back to Programs Menu'
            switch ($nav) {
                '2' { return 'main' }
                '3' { return 'exit' }
            }
        } else {
            Write-Host "`n  Invalid choice." -ForegroundColor Red
            Start-Sleep -Milliseconds 800
        }
    }
}
