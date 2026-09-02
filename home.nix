{ config, pkgs, ... }:

{
  home.username = "ethant";
  home.homeDirectory = "/home/ethant";
  home.stateVersion = "25.11";

  home.file.".local/share/fonts/ChicagoKare-Regular.ttf".source = ./fonts/ChicagoKare-Regular.ttf;

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

  # System info fetch — Gruvbox palette on default NixOS logo
  programs.fastfetch = {
    enable = true;
    settings = {
      logo.color = {
        "1" = "38;2;131;165;152";   # gruvbox blue  (#83a598)
        "2" = "38;2;142;192;124";   # gruvbox aqua  (#8ec07c)
      };
      display.color = {
        title = "1;38;2;250;189;47"; # gruvbox yellow bold (#fabd2f)
        keys  = "38;2;254;128;25";   # gruvbox orange (#fe8019)
      };
      modules = [
        "title"
        "separator"
        "os"
        "host"
        "kernel"
        "uptime"
        "packages"
        "shell"
        "display"
        "wm"
        "terminal"
        "terminalfont"
        "cpu"
        "gpu"
        "memory"
        "swap"
        "disk"
        "localip"
        "locale"
        "break"
        "colors"
      ];
    };
  };

  # Terminal
  programs.kitty = {
    enable = true;
    settings = {
      font_family = "JetBrainsMono Nerd Font";
      font_size = 12;
      window_padding_width = 8;

      background_opacity = "0.90";

      # Gruvbox Material Dark (Medium) — background overridden to neutral dark grey
      foreground = "#D4BE98";
      background = "#2A2A2A";
      selection_foreground = "#D4BE98";
      selection_background = "#45403D";
      cursor = "#D4BE98";
      cursor_text_color = "#2A2A2A";

      color0 = "#32302F";
      color8 = "#45403D";
      color1 = "#EA6962";
      color9 = "#EA6962";
      color2 = "#A9B665";
      color10 = "#A9B665";
      color3 = "#D8A657";
      color11 = "#D8A657";
      color4 = "#7DAEA3";
      color12 = "#7DAEA3";
      color5 = "#D3869B";
      color13 = "#D3869B";
      color6 = "#89B482";
      color14 = "#89B482";
      color7 = "#D4BE98";
      color15 = "#D4BE98";
    };
  };

  # Status bar — Mac Classic menubar
  programs.waybar = {
    enable = true;
    settings = [{
      layer = "top";
      position = "top";
      height = 24;
      modules-left = [ "custom/nixos" "hyprland/workspaces" ];
      modules-center = [];
      modules-right = [ "pulseaudio" "network" "battery" "clock" ];

      "custom/nixos" = {
        format = "";
        tooltip = false;
      };

      "hyprland/workspaces" = {
        format = "{name} {windows}";
        format-window-separator = " ";
        on-click = "activate";
        sort-by-number = true;
        window-rewrite-default = "";
        window-rewrite = {
          "class<firefox>" = "";
          "class<kitty>" = "";
          "class<[Cc]ode>" = "";
          "class<[Nn]autilus>" = "";
          "class<[Cc]hrom(e|ium)>" = "";
          "class<discord>" = "";
          "class<[Ss]potify>" = "";
          "class<[Ss]lack>" = "";
          "class<obsidian>" = "";
          "title<.*[Yy]ou[Tt]ube.*>" = "";
        };
      };

      pulseaudio = {
        format = "  {volume}%";
        format-muted = "  muted";
        on-click = "pavucontrol";
      };

      network = {
        format-wifi = "  {essid}";
        format-ethernet = "  wired";
        format-disconnected = "  offline";
        tooltip-format = "{ifname}: {ipaddr}";
      };

      battery = {
        format = "{icon}  {capacity}%";
        format-charging = "  {capacity}%";
        format-icons = [ "" "" "" "" "" ];
        states = {
          warning = 30;
          critical = 15;
        };
      };

      clock = {
        format = "{:%b %d   %I:%M %p}";
        tooltip-format = "{:%A, %B %d, %Y}";
      };
    }];
    style = ''
      * {
        font-family: "Chicago Kare", "Symbols Nerd Font", monospace;
        font-size: 12px;
        border: none;
        border-radius: 0;
        padding: 0;
        margin: 0;
        min-height: 0;
      }
      window#waybar {
        background-color: #c0c0c0;
        color: #000000;
        border-bottom: 1px solid #404040;
      }
      #custom-nixos {
        font-size: 14px;
        padding: 0 10px;
        color: #000000;
      }
      #workspaces {
        padding: 0 4px;
      }
      #workspaces button {
        padding: 1px 10px;
        margin: 3px 2px;
        color: #000000;
        background: #c0c0c0;
        border-radius: 0;
        border: 1px solid #404040;
        box-shadow: inset 1px 1px 0 #ffffff, inset -1px -1px 0 #808080;
        text-shadow: none;
      }
      #workspaces button:hover {
        background: #d0d0d0;
        box-shadow: inset 1px 1px 0 #ffffff, inset -1px -1px 0 #808080;
      }
      #workspaces button.active {
        background: #b0b0b0;
        box-shadow: inset 1px 1px 0 #808080, inset -1px -1px 0 #ffffff;
        padding: 2px 9px 0 11px;
      }
      #pulseaudio, #network, #battery, #clock {
        padding: 0 10px;
        color: #000000;
      }
      #battery.warning {
        color: #806000;
      }
      #battery.critical {
        color: #800000;
      }
    '';
  };

  # Wallpaper
  services.hyprpaper = {
    enable = true;
    settings = {
      preload = [ "/home/ethant/Downloads/Powerline.png" ];
      wallpaper = [ ",/home/ethant/Downloads/Powerline.png" ];
    };
  };

  # Hyprland
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      monitor = [
        "DP-1,1920x1080@144,0x0,1"
        "HDMI-A-2,1440x900@59.887,-1440x0,1"
        ",preferred,auto,1"
      ];

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

      env = [
        "XCURSOR_SIZE,24"
        "WLR_NO_HARDWARE_CURSORS,1"
      ];

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
        "$mod SHIFT, S, exec, grim -g \"$(slurp)\" - | wl-copy"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      exec-once = [
        "waybar"
        "kitty"
      ];
    };
  };

  programs.home-manager.enable = true;
}
