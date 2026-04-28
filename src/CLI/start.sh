#!/usr/bin/env bash
# ============================================================================
# pcHealth — CLI Launcher (Linux)
# Checks dependencies, then starts the CLI elevated via sudo.
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 0. OS version check ───────────────────────────────────────────────────────
# Hard minimum: kernel 6.0 — last supported kernel generation.
# Recommended:  kernel 7.0 — current stable release.
KERNEL_VERSION="$(uname -r)"
KERNEL_MAJOR="$(echo "$KERNEL_VERSION" | cut -d. -f1)"

if [ "$KERNEL_MAJOR" -lt 6 ] 2>/dev/null; then
    echo "[!!] pcHealth cannot run on kernel $KERNEL_VERSION."
    echo "     Minimum required: kernel 6.0."
    echo "     Please update your kernel."
    exit 1
elif [ "$KERNEL_MAJOR" -lt 7 ] 2>/dev/null; then
    echo "[!] Your kernel ($KERNEL_VERSION) is below the recommended version (7.0)."
    echo "    Some features may not work correctly. Consider updating your kernel."
    echo "    https://www.kernel.org/"
    echo ""
fi

# ── 1. Dependency check ───────────────────────────────────────────────────────
echo ''
echo '[pcHealth] Checking dependencies...'

PAD=24
dep_status() {
    local label="$1" ok="$2" optional="${3:-0}"
    local dots
    dots=$(printf '%0.s.' $(seq 1 $((PAD - ${#label}))))
    if [ "$ok" -eq 1 ]; then
        printf '  %s %s OK\n'            "$label" "$dots"
    elif [ "$optional" -eq 1 ]; then
        printf '  %s %s not installed\n' "$label" "$dots"
    else
        printf '  %s %s NOT FOUND\n'    "$label" "$dots"
    fi
}

PWSH_OK=0
command -v pwsh &>/dev/null && PWSH_OK=1

SMARTCTL_OK=0
command -v smartctl &>/dev/null && SMARTCTL_OK=1

dep_status 'PowerShell 7'  "$PWSH_OK"
dep_status 'smartmontools' "$SMARTCTL_OK" 1

# ── 2. Install missing dependencies ──────────────────────────────────────────
if [ "$PWSH_OK" -eq 0 ]; then
    echo ''
    echo '[pcHealth] PowerShell 7 is required to run this application.'
    read -r -p '           Install now? [y/N]: ' answer
    case "$answer" in
        [Yy]*) ;;
        *)
            echo ''
            echo '[!!] Cannot continue without PowerShell 7.'
            exit 1
            ;;
    esac

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
            sudo pacman -S powershell --noconfirm 2>/dev/null || {
                echo '[!!] powershell not in official repos. Install an AUR helper (paru/yay) and re-run,'
                echo '     or install manually: https://aka.ms/powershell'
                exit 1
            }
        fi
    }

    echo ''
    echo '[pcHealth] Installing PowerShell 7...'
    case "$DISTRO_ID" in
        cachyos)
            sudo pacman -S powershell --noconfirm 2>/dev/null || install_pwsh_arch
            ;;
        garuda|arch|endeavouros|artix)
            install_pwsh_arch
            ;;
        manjaro)
            sudo pacman -S powershell --noconfirm 2>/dev/null || install_pwsh_arch
            ;;
        ubuntu|debian|linuxmint|pop|elementary|zorin|kali)
            sudo apt-get update -q
            sudo apt-get install -y curl apt-transport-https
            curl -sSL https://packages.microsoft.com/keys/microsoft.asc \
                | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc >/dev/null
            # $ID and $VERSION_CODENAME come from /etc/os-release sourced above.
            echo "deb [arch=$(dpkg --print-architecture)] https://packages.microsoft.com/repos/microsoft-${ID}-${VERSION_CODENAME}-prod ${VERSION_CODENAME} main" \
                | sudo tee /etc/apt/sources.list.d/microsoft.list >/dev/null
            sudo apt-get update -q && sudo apt-get install -y powershell
            ;;
        fedora|rhel|centos|almalinux|rocky)
            curl -sSL https://packages.microsoft.com/config/rhel/9/prod.repo \
                | sudo tee /etc/yum.repos.d/microsoft.repo >/dev/null
            sudo dnf install -y powershell
            ;;
        opensuse-leap|opensuse-tumbleweed)
            sudo zypper install -y powershell
            ;;
        *)
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

# ── 3b. Optional: smartmontools ───────────────────────────────────────────────
if [ "$SMARTCTL_OK" -eq 0 ]; then
    echo ''
    echo '[pcHealth] smartmontools is recommended for SMART disk health data (life %, temperature, hours).'
    read -r -p '           Install now? [y/N]: ' answer
    case "$answer" in
        [Yy]*)
            # shellcheck source=/dev/null
            [ -f /etc/os-release ] && . /etc/os-release
            DISTRO_ID="${ID:-unknown}"
            DISTRO_LIKE="${ID_LIKE:-}"

            if   command -v apt-get &>/dev/null; then sudo apt-get install -y smartmontools
            elif command -v dnf     &>/dev/null; then sudo dnf install -y smartmontools
            elif command -v pacman  &>/dev/null; then sudo pacman -S --noconfirm smartmontools
            elif command -v zypper  &>/dev/null; then sudo zypper install -y smartmontools
            else
                echo '[!!] No supported package manager found. Install smartmontools manually.'
            fi

            if command -v smartctl &>/dev/null; then
                echo '[OK] smartmontools installed.'
                SMARTCTL_OK=1
            else
                echo '[!!] Install may need a new shell session to take effect.'
            fi
            ;;
        *)
            echo '     Skipping — SMART data will be limited.'
            ;;
    esac
fi

# ── 3. Launch CLI elevated ────────────────────────────────────────────────────
echo ''
echo '[pcHealth] All dependencies satisfied. Starting pcHealth...'
echo ''
exec sudo pwsh -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT_DIR/app.ps1"
