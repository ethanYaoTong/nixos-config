{ config, pkgs, ... }:

let
  retrosmart-cursor = pkgs.stdenv.mkDerivation {
    pname = "retrosmart-cursor";
    version = "1.2.2-unstable-2026-09-02";
    src = pkgs.fetchFromGitHub {
      owner = "useless-anvil";
      repo = "retrosmart-cursor";
      rev = "29bbe605b73869fadab235c071210ab5cb593503";
      hash = "sha256-xhYZv6l3pgQ2Z0RKKvCAshq3Gn7wr7hK7LMghXDqBII=";
    };
    nativeBuildInputs = with pkgs; [
      bash
      gnumake
      imagemagick
      xorg.xcursorgen
      (python3.withPackages (ps: [ ps.pyyaml ps.pillow ]))
    ];
    buildPhase = ''
      runHook preBuild
      patchShebangs build.sh scripts
      ./build.sh all
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/icons
      cp -r build_themes/Linux/* $out/share/icons/
      runHook postInstall
    '';
  };

  hyprRetileWorkspace = pkgs.writeShellApplication {
    name = "hypr-retile-workspace";
    runtimeInputs = with pkgs; [ hyprland jq ];
    text = ''
      ws=$(hyprctl activeworkspace -j | jq -r .id)
      hyprctl clients -j \
        | jq -r ".[] | select(.workspace.id == $ws and .floating == true) | .address" \
        | while read -r addr; do
            hyprctl dispatch settiled "address:$addr"
          done
    '';
  };

  monaco-nerd-fonts = pkgs.stdenv.mkDerivation {
    pname = "monaco-nerd-fonts";
    version = "unstable-2026-09-02";
    src = pkgs.fetchFromGitHub {
      owner = "Karmenzind";
      repo = "monaco-nerd-fonts";
      rev = "cc39ad6314e0ba0035a9110160086eb5b6ff03ee";
      hash = "sha256-T5NCy4mjXAxzNkDPm6vuKE91Jz9MZnsWLrjRPtrH/NQ=";
    };
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/fonts/truetype/monaco-nerd
      find . -type f -name '*.ttf' -exec cp {} $out/share/fonts/truetype/monaco-nerd/ \;
      runHook postInstall
    '';
  };

  pomo-daemon = pkgs.writeShellApplication {
    name = "pomo-daemon";
    runtimeInputs = with pkgs; [ coreutils bash ];
    text = ''
      work=''${1:-25}
      brk=''${2:-5}
      STATE=/tmp/pomo-state
      PID=/tmp/pomo-daemon.pid
      printf '%s\n' "$$" > "$PID"
      cleanup() { printf 'IDLE\n' > "$STATE"; rm -f "$PID"; }
      trap cleanup EXIT SIGTERM SIGINT
      countdown() {
        local label=$1
        local total=$(( $2 * 60 ))
        local i
        for (( i=total; i>0; i-- )); do
          printf '%s %02d:%02d\n' "$label" "$(( i/60 ))" "$(( i%60 ))" > "$STATE"
          sleep 1
        done
      }
      while true; do
        countdown WORK "$work"
        countdown BREAK "$brk"
      done
    '';
  };

  pomo-status = pkgs.writeShellApplication {
    name = "pomo-status";
    runtimeInputs = with pkgs; [ coreutils ];
    text = ''
      state=$(cat /tmp/pomo-state 2>/dev/null || printf 'IDLE')
      if [ "$state" = "IDLE" ]; then
        printf '󰔛\n'
      else
        printf '%s\n' "$state"
      fi
    '';
  };

  pomo-popup =
    let
      python = pkgs.python3.withPackages (ps: with ps; [ pygobject3 ]);
      typelibs = with pkgs; [
        gtk3 pango.out at-spi2-core gdk-pixbuf glib.out gobject-introspection harfbuzz
      ];
      typelib-path = pkgs.lib.concatMapStringsSep ":"
        (p: "${p}/lib/girepository-1.0") typelibs;
      pyScript = pkgs.writeTextFile {
        name = "pomo-popup.py";
        text = ''
          import gi, os, signal, subprocess
          gi.require_version('Gtk', '3.0')
          from gi.repository import Gtk, GLib, Gdk

          STATE = '/tmp/pomo-state'
          PID_F = '/tmp/pomo-daemon.pid'
          DAEMON = '${pomo-daemon}/bin/pomo-daemon'

          CSS = b"""
          * { font-family: "Chicago Kare", sans-serif; font-size: 13px; }
          window { background-color: #c0c0c0; }
          #status {
            font-size: 15px; font-weight: bold; color: #000000;
            padding: 4px; min-width: 140px;
          }
          spinbutton, spinbutton text, entry {
            background-color: #ffffff; color: #000000;
            border: 1px solid #808080; border-radius: 0;
          }
          button {
            background: #c0c0c0; background-image: none; border-radius: 0;
            border: 1px solid #404040; color: #000000; padding: 3px 14px;
            box-shadow: inset 1px 1px 0 #ffffff, inset -1px -1px 0 #808080;
          }
          button:hover { background-color: #d0d0d0; background-image: none; }
          button:active { box-shadow: inset 1px 1px 0 #808080, inset -1px -1px 0 #ffffff; }
          separator { background-color: #808080; min-height: 1px; }
          label { color: #000000; }
          """

          class Win(Gtk.Window):
            def __init__(self):
              super().__init__(title="Pomodoro")
              self.set_resizable(False)
              self.set_border_width(12)
              p = Gtk.CssProvider()
              p.load_from_data(CSS)
              Gtk.StyleContext.add_provider_for_screen(
                Gdk.Screen.get_default(), p, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

              box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
              self.add(box)

              self.lbl = Gtk.Label(label="Idle")
              self.lbl.set_name("status")
              box.pack_start(self.lbl, False, False, 0)
              box.pack_start(Gtk.Separator(), False, False, 0)

              g = Gtk.Grid(row_spacing=6, column_spacing=10)
              box.pack_start(g, False, False, 0)
              g.attach(Gtk.Label(label="Work (min):", xalign=0.0), 0, 0, 1, 1)
              self.ws = Gtk.SpinButton.new_with_range(1, 90, 1)
              self.ws.set_value(25)
              g.attach(self.ws, 1, 0, 1, 1)
              g.attach(Gtk.Label(label="Break (min):", xalign=0.0), 0, 1, 1, 1)
              self.bs = Gtk.SpinButton.new_with_range(1, 30, 1)
              self.bs.set_value(5)
              g.attach(self.bs, 1, 1, 1, 1)

              box.pack_start(Gtk.Separator(), False, False, 0)
              bb = Gtk.Box(spacing=8, homogeneous=True)
              st = Gtk.Button(label="Start"); st.connect("clicked", self.start)
              sp = Gtk.Button(label="Stop");  sp.connect("clicked", self.stop)
              bb.pack_start(st, True, True, 0)
              bb.pack_start(sp, True, True, 0)
              box.pack_start(bb, False, False, 0)

              GLib.timeout_add(500, self.tick)
              self.tick()

            def tick(self):
              try:    st = open(STATE).read().strip()
              except Exception: st = "IDLE"
              self.lbl.set_text(st if st != "IDLE" else "Idle")
              return True

            def start(self, _):
              if os.path.exists(PID_F):
                try: os.kill(int(open(PID_F).read()), signal.SIGTERM)
                except Exception: pass
              subprocess.Popen(
                [DAEMON, str(int(self.ws.get_value())), str(int(self.bs.get_value()))],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

            def stop(self, _):
              if os.path.exists(PID_F):
                try: os.kill(int(open(PID_F).read()), signal.SIGTERM)
                except Exception: pass
              with open(STATE, 'w') as f: f.write("IDLE\n")

          GLib.set_prgname("pomodoro-popup")
          GLib.set_application_name("Pomodoro")
          w = Win()
          w.connect("destroy", Gtk.main_quit)
          w.show_all()
          Gtk.main()
        '';
      };
    in pkgs.writeShellApplication {
      name = "pomo-popup";
      text = ''
        export GI_TYPELIB_PATH="${typelib-path}"
        exec ${python}/bin/python3 ${pyScript}
      '';
    };

  pomo-toggle = pkgs.writeShellApplication {
    name = "pomo-toggle";
    runtimeInputs = with pkgs; [ hyprland procps ];
    text = ''
      if pgrep -f pomo-popup >/dev/null 2>&1; then
        hyprctl dispatch closewindow "class:pomodoro-popup"
      else
        ${pomo-popup}/bin/pomo-popup &
      fi
    '';
  };

in
{
  home.username = "ethant";
  home.homeDirectory = "/home/ethant";
  home.stateVersion = "25.11";

  home.sessionPath = [ "$HOME/.config/emacs/bin" ];

  home.file.".local/share/fonts/ChicagoKare-Regular.ttf".source = ./fonts/ChicagoKare-Regular.ttf;

  home.pointerCursor = {
    package = retrosmart-cursor;
    name = "retrosmart-xcursor-mac-ish-gruvbox";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
    hyprcursor.enable = true;
  };

  home.packages = with pkgs; [
    # Terminal utilities
    btop
    ripgrep
    fd
    unzip
    wget
    curl
    # Hyprland ecosystem
    wl-clipboard
    grim
    slurp
    # Editors
    vscode-fhs
    emacs-pgtk
    # Languages
    python3
    # Brightness control
    brightnessctl
    # Apps
    obsidian
    pomo-daemon pomo-status pomo-popup pomo-toggle
    # Fonts
    monaco-nerd-fonts
  ];

  # Waybar dropdown menu (GTK XML, click-triggered from custom/power module)
  home.file.".config/waybar/power_menu.xml".source = ./waybar/power_menu.xml;
  home.file.".config/waybar/pomodoro_menu.xml".source = ./waybar/pomodoro_menu.xml;

  # Shell
  programs.bash = {
    enable = true;
    shellAliases = {
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#laptop";
    };
  };

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

    plugins = with pkgs.vimPlugins; [
      gruvbox-material
    ];

    extraLuaConfig = ''
      vim.opt.termguicolors = true
      vim.opt.background = "dark"
      vim.opt.clipboard = "unnamedplus"

      -- Gruvbox Material — matches kitty palette
      vim.g.gruvbox_material_background = "medium"
      vim.g.gruvbox_material_foreground = "material"
      -- 2 = transparent background + transparent signcolumn/foldcolumn,
      -- so kitty's blurred background shows through nvim
      vim.g.gruvbox_material_transparent_background = 2
      vim.g.gruvbox_material_better_performance = 1

      vim.cmd.colorscheme("gruvbox-material")
    '';
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
      font_family = "Monaco Nerd Font Mono";
      font_size = 12;
      window_padding_width = 8;
      disable_ligatures = "always";
      # disable_ligatures only covers programming ligatures (calt); fi/fl are
      # standard typography ligatures (liga/dlig) and need font_features.
      font_features = "MonacoNFM -liga -dlig";

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

  # App launcher — Mac Classic Apple menu style
  programs.rofi = {
    enable = true;
    theme = ./rofi/mac-classic.rasi;
    extraConfig = {
      modi = "drun";
      show-icons = true;
      drun-display-format = "{name}";
      disable-history = false;
      hide-scrollbar = true;
      display-drun = "";
      sidebar-mode = false;
    };
  };

  # Status bar — Mac Classic menubar
  programs.waybar = {
    enable = true;
    settings = [{
      layer = "top";
      position = "top";
      height = 26;
      modules-left = [ "custom/nixos" "hyprland/workspaces" ];
      modules-center = [];
      modules-right = [ "custom/pomodoro" "pulseaudio" "network" "battery" "clock" ];

      "custom/nixos" = {
        format = "";
        tooltip = false;
        menu = "on-click";
        menu-file = "${config.home.homeDirectory}/.config/waybar/power_menu.xml";
        menu-actions = {
          shutdown = "systemctl poweroff";
          reboot = "systemctl reboot";
          suspend = "systemctl suspend";
          logout = "hyprctl dispatch exit";
        };
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
          "class<discord>" = "";
          "class<[Ss]potify>" = "";
          "class<[Ss]lack>" = "";
          "class<obsidian>" = "";
          "title<.*[Yy]ou[Tt]ube.*>" = "";
        };
      };

      "custom/pomodoro" = {
        format = "{}";
        exec = "${pomo-status}/bin/pomo-status";
        interval = 1;
        on-click = "${pomo-toggle}/bin/pomo-toggle";
        tooltip = false;
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
        font-size: 15px;
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
        padding: 1px 0 2px;
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
      #custom-pomodoro {
        padding: 0 10px;
        color: #000000;
        min-width: 90px;
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
      /* Native GTK dropdown fired by waybar's menu feature */
      menu {
        background-color: #c0c0c0;
        color: #000000;
        border: 1px solid #404040;
        border-radius: 0;
        padding: 3px 0;
        box-shadow:
          inset 1px 1px 0 #ffffff,
          inset -1px -1px 0 #808080,
          2px 2px 0 rgba(0, 0, 0, 0.35);
      }
      menu menuitem {
        padding: 4px 18px;
        color: #000000;
        font-family: "Chicago Kare", "Symbols Nerd Font", monospace;
        font-size: 13px;
      }
      menu menuitem:hover {
        background-color: #7DAEA3;
        color: #000000;
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

  # Syncthing — sync ~/org between this PC and macbook
  services.syncthing.enable = true;

  # Hyprland
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      monitor = [
        "DP-1,1920x1080@144,0x0,1"
        "HDMI-A-2,1440x900@59.887,-1440x0,1"
        ",preferred,auto,1"
      ];

      # Pin workspaces to monitors: 1-5 on main (DP-1), 10 dedicated to HDMI-A-2.
      # New workspaces default to the focused monitor, which is DP-1.
      workspace = [
        "1, default:true, persistent:true"
        "2, persistent:true"
        "3, persistent:true"
        "4, persistent:true"
        "5, persistent:true"
        "10, monitor:HDMI-A-2, default:true, persistent:true"
      ];

      general = {
        gaps_in = 3;
        gaps_out = 5;
        border_size = 2;
        "col.active_border" = "rgba(cba6f7ff) rgba(89b4faff) 45deg";
        "col.inactive_border" = "rgba(595959aa)";
        layout = "dwindle";
      };

      decoration = {
        rounding = 0;
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
          "windows, 1, 4, myBezier"
          "windowsOut, 1, 4, default, popin 80%"
          "border, 1, 5, default"
          "fade, 1, 4, default"
          "workspaces, 0, 1, default"
        ];
      };

      input = {
        kb_layout = "us";
        follow_mouse = 1;
        touchpad.natural_scroll = true;
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
        "$mod, T, settiled"
        "$mod SHIFT, T, exec, ${hyprRetileWorkspace}/bin/hypr-retile-workspace"
        "ALT, Space, exec, rofi -show drun"
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
        "$mod, 0, workspace, 10"
        # Move to workspace
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 0, movetoworkspace, 10"
        # Screenshot
        "$mod SHIFT, S, exec, grim -g \"$(slurp)\" - | wl-copy"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      # Media keys — volume knob, mute, playback (works while locked)
      bindel = [
        ", XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86MonBrightnessUp, exec, brightnessctl set 5%+"
        ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      ];
      bindl = [
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
      ];

      windowrulev2 = [
        "float, class:^(pomodoro-popup)$"
        "size 300 230, class:^(pomodoro-popup)$"
        "move cursor -150 0, class:^(pomodoro-popup)$"
        "animation slide, class:^(pomodoro-popup)$"
        "noinitialfocus, class:^(pomodoro-popup)$"
      ];

      exec-once = [
        "waybar"
        "kitty"
      ];
    };
  };

  programs.home-manager.enable = true;
}
