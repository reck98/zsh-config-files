#!/usr/bin/env bash
set -e
set -o pipefail

# ==============================================================================
# VM BOOTSTRAP SCRIPT (FINAL POLISH)
# ==============================================================================

MODE="install"
CI_MODE=false
LOG_FILE="/tmp/vm_bootstrap.log"

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    install|uninstall|status)
      MODE="$1"; shift ;;
    --ci)
      CI_MODE=true; shift ;;
    *)
      echo "Unknown argument: $1"
      echo "Usage: $0 [install|uninstall|status] [--ci]"
      exit 1 ;;
  esac
done

# --- Logging ---
# Redirect generic output to log file, keep stderr visible
exec > >(tee -a "$LOG_FILE") 2>&1

# --- Colors ---
BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

# ==============================================================================
# Helper functions
# ==============================================================================

pause() {
  [[ -t 1 && "$CI_MODE" == "false" ]] && sleep "${1:-1}"
}

section() {
  echo ""
  echo -e "${BOLD}${BLUE}======================================================${RESET}"
  echo -e "${BOLD}${BLUE}  $1${RESET}"
  echo -e "${BOLD}${BLUE}======================================================${RESET}"
  echo ""
  pause 1
}

info()    { echo "  [INFO]  $1"; pause 0.5; }
success() { echo -e "  ${GREEN}[OK]${RESET}    $1\n"; pause 1; }
warn()    { echo -e "  ${YELLOW}[WARN]${RESET}  $1"; pause 1; }
fatal()   { echo -e "\n  ${RED}[ERROR]${RESET} $1\n"; exit 1; }

# ==============================================================================
# Pre-flight checks
# ==============================================================================

# Only require Root/Sudo for install/uninstall operations
if [[ "$MODE" != "status" ]]; then
  [[ "$EUID" -ne 0 ]] || fatal "Do not run as root. Use a sudo-enabled user."
  command -v sudo >/dev/null || fatal "sudo is required."
fi

# Detect package manager
PM="unknown"
command -v apt >/dev/null && PM="apt"
command -v dnf >/dev/null && PM="dnf"
command -v pacman >/dev/null && PM="pacman"
[[ "$PM" != "unknown" ]] || fatal "Unsupported Linux distribution."

# ==============================================================================
# Sudo & Cleanup Handlers (Scoped)
# ==============================================================================

SUDO_PID=""

# Define cleanup function
cleanup() {
  # Kill background sudo loop if active
  if [[ -n "$SUDO_PID" ]]; then
    kill "$SUDO_PID" 2>/dev/null || true
  fi
  
  # Remove policy lock only if we are in apt mode and the file exists
  if [[ "$PM" == "apt" && -f /usr/sbin/policy-rc.d ]]; then
     # Use a quiet check to avoid 'sudo' password prompt if token expired
     if sudo -n true 2>/dev/null; then
        sudo rm -f /usr/sbin/policy-rc.d 2>/dev/null || true
     fi
  fi
}
trap cleanup EXIT

# Start Sudo Keep-Alive (ONLY for install/uninstall)
if [[ "$MODE" != "status" ]]; then
  sudo -v
  ( while true; do sudo -v; sleep 50; done; ) &
  SUDO_PID=$!
  
  # Defensive: Check for leftover locks from previous runs
  if [[ "$PM" == "apt" && -f /usr/sbin/policy-rc.d ]]; then
    warn "Found leftover policy-rc.d from previous run. Removing."
    sudo rm -f /usr/sbin/policy-rc.d
  fi
fi

# ==============================================================================
# STATUS MODE
# ==============================================================================

if [[ "$MODE" == "status" ]]; then
  section "System Status"

  check_bin() {
    if command -v "$1" >/dev/null; then
      # FIX: Added '|| true' to prevent pipefail crash if 'head' closes pipe early
      VER=$($1 --version 2>&1 | head -n1 || true)
      echo "  [OK] $1 $VER"
    else
      echo "  [--] $1 not installed"
    fi
  }

  check_service() {
    if command -v systemctl >/dev/null; then
       if systemctl is-active "$1" >/dev/null 2>&1; then
         echo -e "  ${GREEN}[RUNNING]${RESET} $1"
       else
         echo -e "  [STOPPED] $1"
       fi
    fi
  }

  check_bin node
  check_bin pm2
  check_bin docker
  check_bin nginx
  check_bin cloudflared

  echo ""
  echo "  Services:"
  check_service docker
  check_service nginx
  exit 0
fi

# ==============================================================================
# UNINSTALL MODE
# ==============================================================================

if [[ "$MODE" == "uninstall" ]]; then
  section "Safe Uninstall"

  warn "Removing Node, Docker, Nginx, PM2, Cloudflared."
  warn "User groups and shells are untouched."

  command -v npm >/dev/null && sudo npm uninstall -g pm2 >/dev/null 2>&1 || true

  case "$PM" in
    apt)
      sudo apt remove -y nodejs nginx docker.io docker-compose docker-compose-plugin cloudflared || true ;;
    dnf)
      sudo dnf remove -y nodejs nginx docker docker-compose cloudflared || true ;;
    pacman)
      sudo pacman -Rns --noconfirm nodejs npm nginx docker cloudflared || true ;;
  esac

  warn "User '$USER' may still belong to the docker group."
  success "Uninstall complete. Log out and log back in."
  exit 0
fi

# ==============================================================================
# INSTALL MODE
# ==============================================================================

section "Starting Installation ($PM detected)"
info "Services will NOT be auto-started."

# APT no-autostart policy
if [[ "$PM" == "apt" ]]; then
  info "Applying no-autostart policy"
  echo "exit 101" | sudo tee /usr/sbin/policy-rc.d >/dev/null
  sudo chmod +x /usr/sbin/policy-rc.d
fi

# Update
section "Updating Package Lists"
case "$PM" in
  apt) sudo apt update -qq ;;
  dnf) sudo dnf makecache -q ;;
  pacman) sudo pacman -Sy --quiet ;;
esac
success "Package lists updated"

# Base utilities
section "Installing Base Utilities"
COMMON="curl wget git unzip zip tar htop ca-certificates"
case "$PM" in
  apt)
    sudo apt install -y $COMMON build-essential python3 python3-pip ;;
  dnf)
    sudo dnf install -y $COMMON gcc gcc-c++ make python3 python3-pip ;;
  pacman)
    sudo pacman -S --noconfirm $COMMON base-devel python python-pip ;;
esac
success "Base utilities installed"

# Node.js
section "Installing Node.js (LTS)"
if ! command -v node >/dev/null; then
  # Pipefail safety: ensure curl errors stop script, but downstream logic holds
  case "$PM" in
    apt)
      curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
      sudo apt install -y nodejs ;;
    dnf)
      curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
      sudo dnf install -y nodejs ;;
    pacman)
      sudo pacman -S --noconfirm nodejs npm ;;
  esac
  success "Node.js installed"
else
  info "Node.js already installed"
fi

# PM2
section "Installing PM2"
command -v npm >/dev/null \
  && sudo npm install -g pm2 >/dev/null 2>&1 \
  && success "PM2 installed" \
  || warn "npm missing, skipping PM2"

# Docker
section "Installing Docker (not started)"
case "$PM" in
  apt) sudo apt install -y docker.io ;;
  dnf) sudo dnf install -y docker ;;
  pacman) sudo pacman -S --noconfirm docker ;;
esac

# Docker Compose (best effort)
if [[ "$PM" == "apt" ]]; then
  if apt-cache show docker-compose-plugin >/dev/null 2>&1; then
    sudo apt install -y docker-compose-plugin
  elif apt-cache show docker-compose >/dev/null 2>&1; then
    sudo apt install -y docker-compose
  fi
elif [[ "$PM" == "dnf" ]]; then
  sudo dnf install -y docker-compose || true
elif [[ "$PM" == "pacman" ]]; then
  sudo pacman -S --noconfirm docker-compose || true
fi

getent group docker >/dev/null && sudo usermod -aG docker "$USER"
success "Docker installed (stopped)"

# Nginx
section "Installing Nginx"
case "$PM" in
  apt) sudo apt install -y nginx ;;
  dnf) sudo dnf install -y nginx ;;
  pacman) sudo pacman -S --noconfirm nginx ;;
esac
success "Nginx installed (stopped)"

# Cloudflared
section "Installing Cloudflared"
if ! command -v cloudflared >/dev/null; then
  ARCH=$(uname -m)
  [[ "$ARCH" == "x86_64" ]] && CF_ARCH="amd64" || CF_ARCH="arm64"

  info "Downloading Cloudflared ($CF_ARCH)"
  # Added -f to curl to fail fast on 404
  curl -fL -o /tmp/cloudflared \
    "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$CF_ARCH"
  sudo mv /tmp/cloudflared /usr/local/bin/cloudflared
  sudo chmod +x /usr/local/bin/cloudflared
  success "Cloudflared installed"
else
  info "Cloudflared already installed"
fi

# ==============================================================================
# FINAL SUMMARY
# ==============================================================================

section "Bootstrap Complete"

echo "  State:"
echo "   - Docker:      Installed | STOPPED"
echo "   - Nginx:       Installed | STOPPED"
echo "   - Cloudflared: Installed | UNCONFIGURED"
echo ""
echo "  Next steps:"
echo "   1. Log out and log back in (docker group permissions)"
echo "   2. Start services manually when needed"
echo ""
success "VM bootstrap finished cleanly"
exit 0
