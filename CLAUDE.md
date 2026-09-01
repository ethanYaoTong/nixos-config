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
- [ ] Hyprland configured (enabled in system but no dotfiles yet)
- [ ] Rice stack (Waybar, Wofi, Kitty, theming)
- [ ] Dev tools

## Planned Next Steps
1. Scaffold Hyprland config via Home Manager
2. Add terminal (Kitty), launcher (Wofi), status bar (Waybar)
3. Add dev tools / language toolchains
