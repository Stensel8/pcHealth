#Requires -Version 7.0
# ============================================================================
# pcHealth -- Disk Cleanup (Linux)
# Cleans package caches, trims old journal logs, removes unused Flatpak
# runtimes, and clears the thumbnail cache.
# ============================================================================

Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
Write-Host '  Disk Cleanup' -ForegroundColor Cyan
Write-Host "$('=' * 60)`n" -ForegroundColor Cyan

$osRelease  = Get-LinuxDistroInfo
$distroId   = $osRelease['ID']
$distroLike = $osRelease['ID_LIKE']

Write-Host "  Distro: $($osRelease['PRETTY_NAME'])`n" -ForegroundColor DarkGray

function Invoke-Cleanup {
    param([string]$Label, [scriptblock]$Action)
    Write-Host "[>>] $Label" -ForegroundColor Yellow
    & $Action 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Done.`n" -ForegroundColor Green
    } else {
        Write-Host "[--] Exit code $LASTEXITCODE (may be non-fatal).`n" -ForegroundColor DarkGray
    }
}

# ── Package cache ─────────────────────────────────────────────────────────────

$archIds = @('arch', 'cachyos', 'garuda', 'manjaro', 'endeavouros', 'artix')

if ($distroId -in $archIds -or $distroLike -match 'arch') {
    if (Get-Command paccache -ErrorAction SilentlyContinue) {
        Invoke-Cleanup 'Clearing pacman cache (keeping last 2 versions)...' { sudo paccache -rk2 }
    }
    # Only remove orphans when there is actually something to remove;
    # passing an empty list to pacman -Rns causes a non-zero exit and confuses users.
    $orphans = @(& pacman -Qdtq 2>$null)
    if ($orphans.Count -gt 0) {
        Invoke-Cleanup 'Removing unneeded pacman dependencies...' { sudo pacman -Rns $orphans --noconfirm }
    } else {
        Write-Host "[--] No unneeded pacman dependencies found, skipping.`n" -ForegroundColor DarkGray
    }
} elseif ($distroId -in @('ubuntu', 'debian', 'linuxmint', 'pop', 'elementary', 'zorin', 'kali') -or $distroLike -match 'debian|ubuntu') {
    Invoke-Cleanup 'Removing unneeded apt packages...' { sudo apt autoremove -y }
    Invoke-Cleanup 'Cleaning apt cache...'             { sudo apt autoclean }
} elseif ($distroId -in @('fedora', 'rhel', 'centos', 'almalinux', 'rocky') -or $distroLike -match 'fedora|rhel') {
    Invoke-Cleanup 'Removing unneeded dnf packages...' { sudo dnf autoremove -y }
    Invoke-Cleanup 'Cleaning dnf cache...'             { sudo dnf clean all }
} elseif ($distroId -in @('opensuse-leap', 'opensuse-tumbleweed', 'sles') -or $distroLike -match 'suse') {
    Invoke-Cleanup 'Cleaning zypper cache...' { sudo zypper clean --all }
} else {
    Write-Host "[--] Package cache: distro not recognised, skipping.`n" -ForegroundColor DarkGray
}

# ── Journal logs ──────────────────────────────────────────────────────────────

if (Get-Command journalctl -ErrorAction SilentlyContinue) {
    Invoke-Cleanup 'Vacuuming journal logs (keeping last 7 days)...' {
        sudo journalctl --vacuum-time=7d
    }
}

# ── Flatpak unused runtimes ───────────────────────────────────────────────────

if (Get-Command flatpak -ErrorAction SilentlyContinue) {
    Invoke-Cleanup 'Removing unused Flatpak runtimes...' { sudo flatpak uninstall --unused -y }
}

# ── Thumbnail cache ───────────────────────────────────────────────────────────

$thumbDir = Join-Path $env:HOME '.cache/thumbnails'
if (Test-Path $thumbDir) {
    $sizeMB = [math]::Round(
        (Get-ChildItem $thumbDir -Recurse -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum / 1MB, 1)
    Invoke-Cleanup "Clearing thumbnail cache ($sizeMB MB)..." {
        Get-ChildItem (Join-Path $env:HOME '.cache/thumbnails') -Recurse -File -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "  Disk cleanup complete.`n" -ForegroundColor Green
