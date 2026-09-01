{ config, pkgs, ... }:

{
  home.username = "ethant";
  home.homeDirectory = "/home/ethant";
  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    # Terminal utilities
    btop
    ripgrep
    fd
    unzip
    wget
    curl
    # Hyprland ecosystem
    wofi
    hyprpaper
    wl-clipboard
    grim
    slurp
  ];

  # Shell
  programs.bash.enable = true;

  # Git
  programs.git = {
    enable = true;
    userName = "Ethan Tong";
    userEmail = "ethantong1337@gmail.com";
  };

  # Neovim
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
  };

  # Terminal
  programs.kitty = {
    enable = true;
    settings = {
      font_family = "JetBrainsMono Nerd Font";
      font_size = 12;
      background_opacity = "0.95";
      window_padding_width = 8;
    };
  };

  # Status bar
  programs.waybar = {
    enable = true;
    settings = [{
      layer = "top";
      position = "top";
      modules-left = [ "hyprland/workspaces" ];
      modules-center = [ "clock" ];
      modules-right = [ "pulseaudio" "network" "battery" "tray" ];
      clock.format = "{:%H:%M  %a %d %b}";
      network = {
        format-wifi = " {essid}";
        format-ethernet = " connected";
        format-disconnected = "disconnected";
      };
      pulseaudio = {
        format = " {volume}%";
        format-muted = " muted";
      };
      battery = {
        format = "{icon} {capacity}%";
        format-icons = [ "" "" "" "" "" ];
      };
    }];
    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 13px;
      }
      window#waybar {
        background: rgba(30, 30, 46, 0.9);
        color: #cdd6f4;
      }
      #workspaces button {
        padding: 0 8px;
        color: #6c7086;
      }
      #workspaces button.active {
        color: #cdd6f4;
      }
      #clock, #network, #pulseaudio, #battery, #tray {
        padding: 0 12px;
        color: #cdd6f4;
      }
    '';
  };

  # Hyprland
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      monitor = ",preferred,auto,1";

      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        "col.active_border" = "rgba(cba6f7ff) rgba(89b4faff) 45deg";
        "col.inactive_border" = "rgba(595959aa)";
        layout = "dwindle";
      };

      decoration = {
        rounding = 10;
        blur = {
          enabled = true;
          size = 8;
          passes = 2;
        };
        shadow = {
          enabled = true;
          range = 4;
          render_power = 3;
        };
      };

      animations = {
        enabled = true;
        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
        animation = [
          "windows, 1, 7, myBezier"
          "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 10, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, default"
        ];
      };

      input = {
        kb_layout = "us";
        follow_mouse = 1;
        touchpad.natural_scroll = false;
      };

      "$mod" = "SUPER";

      bind = [
        "$mod, Return, exec, kitty"
        "$mod, Q, killactive"
        "$mod, M, exit"
        "$mod, E, exec, nautilus"
        "$mod, V, togglefloating"
        "$mod, R, exec, wofi --show drun"
        "$mod, P, pseudo"
        "$mod, J, togglesplit"
        # Move focus
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"
        # Workspaces
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        # Move to workspace
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        # Screenshot
        ", Print, exec, grim -g \"$(slurp)\" ~/Pictures/screenshot.png"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      exec-once = [
        "waybar"
        "hyprpaper"
      ];
    };
  };

  programs.home-manager.enable = true;
}
