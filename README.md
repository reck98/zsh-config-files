# Zsh Global Configuration Script

A safe, cross-distribution, idempotent shell script to install and uninstall **Zsh with Oh-My-Zsh** and apply a consistent configuration across Linux systems.

This project is designed for **VMs, servers, WSL, and local machines**, with strong safety guarantees to prevent lockouts and broken logins.

---

## Features

* Works on major Linux distributions:

  * Ubuntu / Debian
  * Fedora / RHEL
  * Arch / Manjaro
  * WSL
* Supports **install** and **uninstall** modes
* Safe to re-run multiple times (idempotent)
* Prevents shell-related lockouts
* Does not automatically change the login shell
* Clear, explicit instructions for manual shell switching
* Human-friendly output with TTY-aware delays
* SSH and automation safe
* No interactive prompts inside the script

---

## What This Script Does

### Install Mode

* Installs required packages:

  * `zsh`
  * `git`
  * `curl`
* Installs **Oh-My-Zsh** without changing the default shell
* Installs Zsh plugins:

  * `zsh-autosuggestions`
  * `zsh-syntax-highlighting`
* Applies a managed Zsh configuration block that includes:

  * Shared command history
  * Autosuggestions
  * Clean prompt showing the last three directories
  * A blank line between commands
* Prints clear instructions to manually switch the login shell

### Uninstall Mode

* Safely removes:

  * Oh-My-Zsh
  * Zsh configuration files
  * Zsh package
* Includes lockout protection:

  * Refuses to uninstall if Zsh is still the active login shell
* Prints explicit instructions to log out and log back in after uninstall

---

## Safety Guarantees

This script is written with system safety as the top priority:

* Never runs `chsh` automatically
* Prevents uninstalling Zsh while it is still set as the login shell
* Safe for SSH sessions and remote VMs
* Clear failure messages when manual steps are required
* No destructive operations without checks

---

## Usage

### Install Zsh Configuration

Run locally:

```bash
bash zsh-global-config.sh install
```

Or run directly from GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/reck98/zsh-config-files/main/zsh-global-config.sh | bash -s install
```

After installation, switch your shell manually:

```bash
chsh -s /usr/bin/zsh <username>
```

Then log out and log back in.

---

### Uninstall Zsh Configuration

Run locally:

```bash
bash zsh-global-config.sh uninstall
```

Or run directly from GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/reck98/zsh-config-files/main/zsh-global-config.sh | bash -s uninstall
```

After uninstalling, **log out and log back in** to ensure a clean Bash session.

---

## Supported Package Managers

The script automatically detects and uses:

* `apt` (Ubuntu / Debian)
* `dnf` (Fedora / RHEL)
* `pacman` (Arch / Manjaro)

If no supported package manager is found, the script exits with clear manual instructions.

---

## Design Philosophy

* Explicit over implicit
* Safety over convenience
* Manual shell switching by design
* No hidden side effects
* Clear user communication

This script behaves like a professional system installer rather than a one-off setup script.

---

## Recommended Use Cases

* Cloud virtual machines (AWS, Azure, GCP, DigitalOcean)
* WSL environments
* Development servers
* Fresh Linux installations
* Reproducible shell environments

---

## Requirements

* A non-root user account
* `sudo` access
* Active internet connection

---

## License

MIT License

---

## Maintainer Notes

This script has been hardened against:

* PAM authentication failures
* SSH lockouts
* Missing shells
* Repeated executions
* Partial installations

Contributions should preserve these safety properties.
