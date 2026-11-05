# install-caelestia

One-shot installer for **Hyprland + [Caelestia dots](https://github.com/caelestia-dots/caelestia)** on Arch / CachyOS.
Uses the official `caelestia install` command from [caelestia-cli](https://github.com/caelestia-dots/cli).

## Usage (fresh Arch, root only, no editor needed)

```bash
curl -L -o install-caelestia.sh https://raw.githubusercontent.com/Weitgraven/install-caelestia/main/install-caelestia.sh
bash install-caelestia.sh --greetd
```

Run as root: it creates a normal user (or reuses an existing one), gives it sudo, and continues the install as that user.
Run as a normal user with sudo: it installs straight away.
Already ran an older version? Download it again and re-run the same commands.

### Options
- `--greetd` – install greetd + tuigreet as login screen
- `--spotify`, `--discord`, `--zen`, `--vscode=codium|code` – enable optional Caelestia components
- `--enable=a,b` / `--disable=a,b` – any other components from Caelestia's `manifest.toml`

After reboot, log in as the new user (not root).
Personal tweaks go in `~/.config/caelestia/hypr-vars.lua`, `hypr-user.lua` and `shell.json`. Update with `caelestia update`.
