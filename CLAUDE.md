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

## Rice Theme: Retro Mac Classic
Goal: Mac OS 8/9 aesthetic — flat gray, black text, Chicago typeface, square UI.
Font: Terminus TTF (placeholder). Chicago FLF (.ttf) to be added when sourced.

### Rice Phases
- [ ] Phase 1: Waybar — Mac Classic menubar (IN PROGRESS)
- [ ] Phase 2: Kitty terminal — light bg, retro palette
- [ ] Phase 3: GTK theme + Nautilus — classic Mac window chrome
- [ ] Phase 4: Hyprland borders + polish

## Planned Next Steps
1. Finish Phase 1 Waybar ricing
2. Add dev tools / language toolchains
