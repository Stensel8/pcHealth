#!/usr/bin/env bash
# ============================================================================
# pcHealth — Linux Launcher
# Checks dependencies (PowerShell 7), then starts the CLI elevated via sudo.
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 0. Minimum kernel version: 7.0 ───────────────────────────────────────────
KERNEL_VERSION="$(uname -r)"
KERNEL_MAJOR="${KERNEL_VERSION%%.*}"
if [ "$KERNEL_MAJOR" -lt 7 ] 2>/dev/null; then
    echo "[!!] pcHealth requires Linux kernel 7.0 or higher."
    echo "     Your kernel: $KERNEL_VERSION"
    echo "     Update your kernel and try again."
    exit 1
fi

# ── 1. Ensure PowerShell 7 ────────────────────────────────────────────────────
if ! command -v pwsh &>/dev/null; then
    echo '[pcHealth] PowerShell 7 not found. Attempting installation...'

    if [ ! -f /etc/os-release ]; then
        echo '[!!] Cannot detect distro (/etc/os-release missing).'
        echo '     Install PowerShell manually: https://aka.ms/powershell'
        exit 1
    fi

    # shellcheck source=/dev/null
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    DISTRO_LIKE="${ID_LIKE:-}"

    install_pwsh_arch() {
        if command -v paru &>/dev/null; then
            paru -S powershell-bin --noconfirm
        elif command -v yay &>/dev/null; then
            yay -S powershell-bin --noconfirm
        elif command -v pacman &>/dev/null; then
            # Try official extra repo first (some distros ship it), fall back to AUR message
            sudo pacman -S powershell --noconfirm 2>/dev/null || {
                echo '[!!] powershell not in official repos. Install an AUR helper (paru/yay) and re-run,'
                echo '     or install manually: https://aka.ms/powershell'
                exit 1
            }
        fi
    }

    case "$DISTRO_ID" in
        cachyos)
            # CachyOS ships powershell in its own repos
            sudo pacman -S powershell --noconfirm 2>/dev/null || install_pwsh_arch
            ;;
        garuda|arch|endeavouros|artix)
            install_pwsh_arch
            ;;
        manjaro)
            sudo pacman -S powershell --noconfirm 2>/dev/null || install_pwsh_arch
            ;;
        ubuntu|debian|linuxmint|pop|elementary|zorin|kali)
            # Microsoft APT repo
            sudo apt-get update -q
            sudo apt-get install -y curl apt-transport-https
            curl -sSL https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc >/dev/null
            source_line="deb [arch=$(dpkg --print-architecture)] https://packages.microsoft.com/repos/microsoft-$(. /etc/os-release; echo "$ID")-$(. /etc/os-release; echo "$VERSION_CODENAME")-prod $(. /etc/os-release; echo "$VERSION_CODENAME") main"
            echo "$source_line" | sudo tee /etc/apt/sources.list.d/microsoft.list >/dev/null
            sudo apt-get update -q && sudo apt-get install -y powershell
            ;;
        fedora|rhel|centos|almalinux|rocky)
            curl -sSL https://packages.microsoft.com/config/rhel/9/prod.repo | sudo tee /etc/yum.repos.d/microsoft.repo >/dev/null
            sudo dnf install -y powershell
            ;;
        opensuse-leap|opensuse-tumbleweed)
            sudo zypper install -y powershell
            ;;
        *)
            # ID_LIKE fallback
            if [[ "$DISTRO_LIKE" == *arch* ]]; then
                install_pwsh_arch
            elif [[ "$DISTRO_LIKE" == *debian* || "$DISTRO_LIKE" == *ubuntu* ]]; then
                sudo apt-get update -q && sudo apt-get install -y powershell
            elif [[ "$DISTRO_LIKE" == *fedora* || "$DISTRO_LIKE" == *rhel* ]]; then
                sudo dnf install -y powershell
            else
                echo "[!!] Cannot auto-install PowerShell for distro '$DISTRO_ID'."
                echo '     Install manually: https://aka.ms/powershell'
                exit 1
            fi
            ;;
    esac

    if ! command -v pwsh &>/dev/null; then
        echo '[!!] Installation completed but pwsh was not found. Please restart your shell and try again.'
        exit 1
    fi

    echo '[OK] PowerShell 7 installed.'
fi

# ── 2. Launch CLI elevated ────────────────────────────────────────────────────
exec sudo pwsh -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT_DIR/src/CLI/Start.ps1"
