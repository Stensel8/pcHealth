#Requires -Version 7.0
# ============================================================================
# pcHealth — Update Packages (Linux)
# Reads /etc/os-release to detect the distro, then runs the appropriate
# update command. Falls back to package-manager detection when the distro
# is not specifically recognised.
# ============================================================================

Write-Host "`nDetecting Linux distribution...`n" -ForegroundColor Cyan

# Read distro ID from /etc/os-release
$osRelease = @{}
if (Test-Path '/etc/os-release') {
    Get-Content '/etc/os-release' | ForEach-Object {
        if ($_ -match '^(\w+)=["'']?([^"'']+)["'']?$') {
            $osRelease[$Matches[1]] = $Matches[2]
        }
    }
}
$distroId   = $osRelease['ID']?.ToLower()
$distroLike = $osRelease['ID_LIKE']?.ToLower()
$distroName = $osRelease['NAME'] ?? 'Unknown'

Write-Host "  Distro: $distroName" -ForegroundColor DarkGray

function Invoke-Update {
    param([string]$Label, [scriptblock]$Action)
    Write-Host "`n[>>] $Label" -ForegroundColor Yellow
    & $Action
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n[OK] Update complete.`n" -ForegroundColor Green
    } else {
        Write-Host "`n[!!] Update returned exit code $LASTEXITCODE.`n" -ForegroundColor Red
    }
}

switch ($distroId) {
    'cachyos' {
        Invoke-Update 'Using cachy-update (CachyOS)' { cachy-update }
        return
    }
    'garuda' {
        Invoke-Update 'Using garuda-update (Garuda Linux)' { garuda-update }
        return
    }
    'manjaro' {
        if (Get-Command pamac -ErrorAction SilentlyContinue) {
            Invoke-Update 'Using pamac (Manjaro)' { pamac upgrade --no-confirm }
        } else {
            Invoke-Update 'Using pacman (Manjaro)' { sudo pacman -Syu --noconfirm }
        }
        return
    }
    { $_ -in @('ubuntu', 'debian', 'linuxmint', 'pop', 'elementary', 'zorin', 'kali') } {
        Invoke-Update "Using apt ($distroName)" {
            sudo apt update
            sudo apt upgrade -y
        }
        return
    }
    { $_ -in @('fedora', 'rhel', 'centos', 'almalinux', 'rocky') } {
        Invoke-Update "Using dnf ($distroName)" { sudo dnf upgrade -y }
        return
    }
    { $_ -in @('opensuse-leap', 'opensuse-tumbleweed', 'sles') } {
        Invoke-Update "Using zypper ($distroName)" { sudo zypper update -y }
        return
    }
    { $_ -in @('arch', 'endeavouros', 'artix') } {
        # Prefer AUR helper if available
        if (Get-Command paru -ErrorAction SilentlyContinue) {
            Invoke-Update "Using paru ($distroName)" { paru -Syu --noconfirm }
        } elseif (Get-Command yay -ErrorAction SilentlyContinue) {
            Invoke-Update "Using yay ($distroName)" { yay -Syu --noconfirm }
        } else {
            Invoke-Update "Using pacman ($distroName)" { sudo pacman -Syu --noconfirm }
        }
        return
    }
}

# ID_LIKE fallback — distro wasn't matched by ID, check family
if ($distroLike -match 'arch') {
    Invoke-Update "Using pacman (Arch-based: $distroName)" { sudo pacman -Syu --noconfirm }
} elseif ($distroLike -match 'debian|ubuntu') {
    Invoke-Update "Using apt (Debian-based: $distroName)" {
        sudo apt update
        sudo apt upgrade -y
    }
} elseif ($distroLike -match 'fedora|rhel') {
    Invoke-Update "Using dnf (RHEL-based: $distroName)" { sudo dnf upgrade -y }
} elseif ($distroLike -match 'suse') {
    Invoke-Update "Using zypper (SUSE-based: $distroName)" { sudo zypper update -y }
} else {
    # Last resort: try commands in order
    Write-Host "  Distro '$distroName' not recognised — falling back to command detection.`n" -ForegroundColor DarkGray
    if (Get-Command apt -ErrorAction SilentlyContinue) {
        Invoke-Update 'Using apt' { sudo apt update; sudo apt upgrade -y }
    } elseif (Get-Command dnf -ErrorAction SilentlyContinue) {
        Invoke-Update 'Using dnf' { sudo dnf upgrade -y }
    } elseif (Get-Command pacman -ErrorAction SilentlyContinue) {
        Invoke-Update 'Using pacman' { sudo pacman -Syu --noconfirm }
    } elseif (Get-Command zypper -ErrorAction SilentlyContinue) {
        Invoke-Update 'Using zypper' { sudo zypper update -y }
    } else {
        Write-Host "[!!] No supported package manager found.`n" -ForegroundColor Red
    }
}
