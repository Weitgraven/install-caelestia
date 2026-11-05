#!/usr/bin/env bash
# Instant installer: Hyprland + Caelestia dots (shell, CLI, configs)
# For Arch / CachyOS / other Arch-based distros. Works from a bare TTY, also as root.
#
# Usage:
#   bash install-caelestia.sh [--greetd] [--spotify] [--vscode=codium|code] [--discord] [--zen]
#                             [--enable=comp1,comp2] [--disable=comp1,comp2]
#
#   --greetd   also install & enable greetd + tuigreet as login manager
#   others     map to `caelestia install --enable-components/--disable-components`

set -euo pipefail
SELF="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || true)"   # resolve before cd
cd /   # never inherit a cwd the target user can't read (e.g. /root)

INSTALL_GREETD=0
ENABLE=()
DISABLE=()

for arg in "$@"; do
  case "$arg" in
    --greetd)          INSTALL_GREETD=1 ;;
    --spotify)         ENABLE+=(spotify) ;;
    --discord)         ENABLE+=(discord) ;;
    --zen)             ENABLE+=(zen) ;;
    --vscode=codium)   ENABLE+=(vscodium) ;;
    --vscode|--vscode=code) ENABLE+=(vscode) ;;
    --enable=*)        IFS=, read -ra x <<<"${arg#*=}"; ENABLE+=("${x[@]}") ;;
    --disable=*)       IFS=, read -ra x <<<"${arg#*=}"; DISABLE+=("${x[@]}") ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

c() { printf '\e[1;36m==>\e[0m %s\n' "$*"; }
die() { printf '\e[1;31m!!\e[0m %s\n' "$*" >&2; exit 1; }

command -v pacman >/dev/null || die "pacman not found — this script is for Arch-based distros."

# --- running as root? create a normal user and re-run as them ---------------
# Hyprland/Caelestia must run as a normal user, and makepkg refuses root.
if [[ $EUID -eq 0 ]]; then
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

# Caelestia needs pipewire-jack; with --noconfirm pacman refuses to replace jack2
if pacman -Qq jack2 &>/dev/null; then
  c "Replacing jack2 with pipewire-jack..."
  sudo pacman -Rdd --noconfirm jack2
  sudo pacman -S --needed --noconfirm pipewire-jack
fi

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

# --- remove stale clone from old version of this script ---------------------
# (the CLI would treat ~/.local/share/caelestia as a legacy install)
OLD="$HOME/.local/share/caelestia"
if [[ -d "$OLD/.git" && ! -L "$HOME/.config/hypr" ]] && git -C "$OLD" remote get-url origin 2>/dev/null | grep -q caelestia-dots/caelestia; then
  c "Removing unused clone at $OLD..."
  rm -rf "$OLD"
fi

# --- Caelestia CLI + install -------------------------------------------------
c "Installing caelestia-cli from the AUR..."
"$AUR" -S --needed --noconfirm caelestia-cli

ARGS=(install --noconfirm --aur-helper="$AUR")
if ((${#ENABLE[@]}));  then ARGS+=(--enable-components="$(IFS=,; echo "${ENABLE[*]}")"); fi
if ((${#DISABLE[@]})); then ARGS+=(--disable-components="$(IFS=,; echo "${DISABLE[*]}")"); fi

c "Running: caelestia ${ARGS[*]}"
cd "$HOME"
caelestia "${ARGS[@]}"

# --- optional login manager -------------------------------------------------
if [[ $INSTALL_GREETD -eq 1 ]]; then
  c "Installing greetd + tuigreet..."
  sudo pacman -S --needed --noconfirm greetd greetd-tuigreet
  sudo tee /etc/greetd/config.toml >/dev/null <<'EOF'
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --remember-session --asterisks --cmd start-hyprland"
user = "greeter"
EOF
  # disable other display managers so greetd can take over
  for dm in sddm gdm lightdm ly; do
    if systemctl is-enabled "$dm" &>/dev/null; then sudo systemctl disable "$dm"; fi
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
  • Update later: caelestia update
  • Don't edit files in ~/.config/hypr/ — use the caelestia files above.
EOF
