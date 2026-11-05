#!/usr/bin/env bash
# Instant installer: Hyprland + Caelestia dots (shell, CLI, configs)
# For Arch / CachyOS / other Arch-based distros.
#
# Usage:
#   bash install-caelestia.sh [--greetd] [--spotify] [--vscode=codium|code] [--discord] [--zen]
#
#   --greetd   also install & enable greetd + tuigreet as login manager
#   other flags are passed straight to Caelestia's install.fish
#
# One-liner (after hosting this file somewhere):
#   curl -fsSL https://<your-host>/install-caelestia.sh | bash -s -- --greetd

set -euo pipefail

REPO_URL="https://github.com/caelestia-dots/caelestia.git"
REPO_DIR="$HOME/.local/share/caelestia"   # do NOT move/delete after install (configs are symlinked)
INSTALL_GREETD=0
PASSTHRU=()

for arg in "$@"; do
  case "$arg" in
    --greetd) INSTALL_GREETD=1 ;;
    *) PASSTHRU+=("$arg") ;;
  esac
done

c() { printf '\e[1;36m==>\e[0m %s\n' "$*"; }
die() { printf '\e[1;31m!!\e[0m %s\n' "$*" >&2; exit 1; }

command -v pacman >/dev/null || die "pacman not found — this script is for Arch-based distros."

# --- running as root? create a normal user and re-run as them ---------------
# Hyprland/Caelestia must run as a normal user, and makepkg refuses root.
if [[ $EUID -eq 0 ]]; then
  SELF="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || true)"
  [[ -f "$SELF" ]] || die "Save the script to a file first (don't pipe it), then run: bash install-caelestia.sh"

  c "Running as root — setting up a normal user first."
  pacman -Sy --needed --noconfirm sudo

  read -rp "Username to create/use: " NEWUSER </dev/tty
  [[ "$NEWUSER" =~ ^[a-z_][a-z0-9_-]*$ ]] || die "Invalid username."

  if id "$NEWUSER" &>/dev/null; then
    c "User $NEWUSER exists — adding to wheel."
    usermod -aG wheel "$NEWUSER"
  else
    useradd -m -G wheel -s /bin/bash "$NEWUSER"
    c "Set a password for $NEWUSER:"
    passwd "$NEWUSER" </dev/tty
  fi

  # wheel may use sudo (with password) permanently
  echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
  # temporary passwordless sudo so the install runs unattended; removed afterwards
  echo "$NEWUSER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-caelestia-tmp
  chmod 440 /etc/sudoers.d/10-wheel /etc/sudoers.d/99-caelestia-tmp
  trap 'rm -f /etc/sudoers.d/99-caelestia-tmp' EXIT

  install -m 755 -o "$NEWUSER" "$SELF" "/home/$NEWUSER/install-caelestia.sh"
  c "Continuing install as $NEWUSER..."
  sudo -u "$NEWUSER" -H bash "/home/$NEWUSER/install-caelestia.sh" "$@"
  c "Log in as $NEWUSER (not root) after reboot."
  exit 0
fi

sudo -v || die "sudo access required."

# --- system update + base deps ----------------------------------------------
c "Updating system..."
sudo pacman -Syu --noconfirm

c "Installing base dependencies (git, fish, base-devel, hyprland)..."
sudo pacman -S --needed --noconfirm git fish base-devel hyprland

# --- AUR helper -------------------------------------------------------------
if command -v paru >/dev/null; then
  AUR=paru
elif command -v yay >/dev/null; then
  AUR=yay
else
  c "No AUR helper found — installing yay..."
  tmp=$(mktemp -d)
  git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
  (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
  rm -rf "$tmp"
  AUR=yay
fi
c "Using AUR helper: $AUR"

# --- clone / update dots ----------------------------------------------------
if [[ -d "$REPO_DIR/.git" ]]; then
  c "Caelestia repo exists — pulling latest..."
  git -C "$REPO_DIR" pull --ff-only
else
  c "Cloning Caelestia dots to $REPO_DIR..."
  mkdir -p "$(dirname "$REPO_DIR")"
  git clone "$REPO_URL" "$REPO_DIR"
fi

# --- run official installer -------------------------------------------------
c "Running Caelestia install script..."
fish "$REPO_DIR/install.fish" --noconfirm --aur-helper="$AUR" "${PASSTHRU[@]}"

# --- optional login manager -------------------------------------------------
if [[ $INSTALL_GREETD -eq 1 ]]; then
  c "Installing greetd + tuigreet..."
  sudo pacman -S --needed --noconfirm greetd greetd-tuigreet
  sudo tee /etc/greetd/config.toml >/dev/null <<'EOF'
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --remember-session --asterisks --cmd Hyprland"
user = "greeter"
EOF
  # disable other display managers so greetd can take over
  for dm in sddm gdm lightdm ly; do
    systemctl is-enabled "$dm" &>/dev/null && sudo systemctl disable "$dm" || true
  done
  sudo systemctl enable greetd
fi

# --- done -------------------------------------------------------------------
cat <<EOF

$(c "Done!")
  • Reboot, then log in to Hyprland (the Caelestia shell autostarts).
  • Personal tweaks go in:
      ~/.config/caelestia/hypr-vars.lua
      ~/.config/caelestia/hypr-user.lua
      ~/.config/caelestia/shell.json
  • Update later: $AUR -Syu && git -C $REPO_DIR pull
  • Don't move or delete $REPO_DIR — your configs are symlinked to it.
EOF
