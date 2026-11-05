# install-caelestia

One-shot installer for **Hyprland + [Caelestia dots](https://github.com/caelestia-dots/caelestia)** on Arch / CachyOS.

## Usage (fresh Arch, root only, no editor needed)

```bash
curl -L -o install-caelestia.sh https://raw.githubusercontent.com/Weitgraven/install-caelestia/main/install-caelestia.sh
bash install-caelestia.sh --greetd
```

Run as root: it creates a normal user, gives it sudo, and continues the install as that user.
Run as a normal user with sudo: it installs straight away.

### Options
- `--greetd` – install greetd + tuigreet as login screen
- `--spotify`, `--vscode=codium|code`, `--discord`, `--zen` – passed to Caelestia's `install.fish`

After reboot, log in as the new user (not root).
Don't move/delete `~/.local/share/caelestia` — configs are symlinked to it.
