# NixOS Configuration

## System Info
- User: ethant (Ethan Tong)
- Hostname: nixos
- Architecture: x86_64-linux
- CPU: AMD (microcode enabled)
- Filesystem: btrfs with subvolumes (@, @home)
- Timezone: Australia/Sydney
- NixOS version: 25.11

## Structure
- `/etc/nixos/flake.nix` — flake entry point (nixpkgs + home-manager inputs)
- `/etc/nixos/configuration.nix` — system config
- `/etc/nixos/hardware-configuration.nix` — auto-generated, don't edit
- `/etc/nixos/home.nix` — Home Manager config for ethant
- `/etc/nixos/fonts/` — TTFs installed declaratively via `home.file`

## Boot & Generations
- Dual-booting Windows; systemd-boot menu limited to 10 entries (`boot.loader.systemd-boot.configurationLimit = 10`)
- Weekly systemd timer prunes system profile to the last 10 generations (`systemd.services.nix-generation-cleanup` + `.timers`)
- Manual cleanup: `sudo nix-collect-garbage -d && nix-collect-garbage -d`

## Key Facts
- Flakes enabled: `nix.settings.experimental-features = [ "nix-command" "flakes" ]`
- /etc/nixos is owned by ethant (not root) so Claude can edit files directly
- Git is installed and repo is pushed to GitHub
- Home Manager uses NixOS module approach (not standalone)
  - `useGlobalPkgs = true`
  - `useUserPackages = true`

## Rebuild Command
```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```
(git must be in PATH — it's now permanently installed so no nix-shell wrapper needed)

## Current State
- [x] Flakes set up
- [x] Home Manager added
- [x] Git configured (ethantong1337@gmail.com)
- [x] Hyprland configured (dotfiles in home.nix)
- [x] Waybar, Wofi, Kitty configured
- [x] Wallpaper (hyprpaper, /home/ethant/Downloads/Powerline.png)
- [ ] Dev tools

## Rice Theme: Hybrid — Mac Classic chrome + Gruvbox Material apps
Original goal was pure Mac OS 8/9 (flat gray, Chicago, square UI). Evolved into a hybrid:
system chrome stays Mac Classic; terminal + editor use Gruvbox Material Dark on a neutral
dark grey background so they read as "retro dark" rather than warm gruvbox brown.

### Fonts
- **Chicago Kare** — waybar menubar font. TTF lives at `fonts/ChicagoKare-Regular.ttf`,
  installed via `home.file.".local/share/fonts/ChicagoKare-Regular.ttf"`.
- JetBrainsMono Nerd Font — kitty (code readability wins over aesthetic here).

### Waybar (Mac Classic menubar)
- Chrome `#c0c0c0` background, black text, Chevy-bevel workspace buttons, sharp corners.
- Font: Chicago Kare.

### Kitty
- Gruvbox Material Dark Medium palette (`foreground = #D4BE98`, standard gruvbox ANSI).
- Background overridden to **`#2A2A2A`** (neutral dark grey, not gruvbox's warm `#292828`).
- `background_opacity = 0.90` — Hyprland's global blur (`size 8, passes 2`) shows through.

### Neovim
- `gruvbox-material` plugin, `background = "medium"`, `foreground = "material"` (matches kitty).
- `transparent_background = 2` so kitty's blur bleeds through nvim too (nvim has no native blur).

### Hyprland
- Windows: sharp corners (`rounding = 0`), tight gaps (`gaps_in = 3`, `gaps_out = 5`).
- Global blur enabled (`size 8, passes 2`) — powers the transparent kitty/nvim effect.
- Cursor: **Retrosmart Mac-ish Gruvbox** — packaged as an inline Nix derivation (see `let`
  block at top of home.nix) that builds from `useless-anvil/retrosmart-cursor` and installs
  via `home.pointerCursor` (gtk + x11 + hyprcursor).

### Rice Phases
- [x] Phase 1: Waybar — Mac Classic menubar
- [x] Phase 2: Kitty terminal — Gruvbox Material on dark grey (diverged from "light bg")
- [x] Phase 2b: Neovim theme match — Gruvbox Material transparent
- [x] Phase 2c: Cursor theme — Retrosmart Mac-ish Gruvbox
- [ ] Phase 3: GTK theme + Nautilus — classic Mac window chrome
- [ ] Phase 4: Hyprland borders + further polish

## Planned Next Steps
1. Phase 3: GTK theme (Mac Classic window chrome for Nautilus etc.)
2. Add dev tools / language toolchains
