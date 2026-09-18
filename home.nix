{ config, pkgs, spicetify-nix, ... }:

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
    runtimeInputs = with pkgs; [ coreutils util-linux pulseaudio ];
    text = ''
      phase=''${1:-WORK}
      mins=''${2:-25}
      cur=''${3:-1}
      total=''${4:-4}
      STATE=/tmp/pomo-state
      CTRL=/tmp/pomo-ctrl
      LOCK=/tmp/pomo-daemon.lock
      SOUND="${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"

      # Only one daemon may run at a time; second instance exits immediately.
      exec 200>"$LOCK"
      flock -n 200 || exit 0

      printf 'run\n' > "$CTRL"

      secs=$(( mins * 60 ))
      for (( i=secs; i>0; i-- )); do
        if [ "$(cat "$CTRL" 2>/dev/null || printf stop)" != "run" ]; then
          printf 'IDLE\n' > "$STATE"
          exit 0
        fi
        printf '%s %02d:%02d %d/%d\n' "$phase" "$(( i/60 ))" "$(( i%60 ))" "$cur" "$total" > "$STATE"
        sleep 1
      done

      # Session finished naturally — set READY_<next> or DONE, then beep.
      if [ "$phase" = "WORK" ]; then
        printf 'READY_BREAK %d/%d\n' "$cur" "$total" > "$STATE"
      elif [ "$cur" -ge "$total" ]; then
        printf 'DONE %d/%d\n' "$cur" "$total" > "$STATE"
      else
        printf 'READY_WORK %d/%d\n' "$(( cur + 1 ))" "$total" > "$STATE"
      fi
      paplay "$SOUND" || true
    '';
  };

  pomo-status = pkgs.writeShellApplication {
    name = "pomo-status";
    runtimeInputs = with pkgs; [ coreutils ];
    text = ''
      state=$(cat /tmp/pomo-state 2>/dev/null || printf 'IDLE')
      # shellcheck disable=SC2086
      set -- $state
      kind=''${1:-IDLE}
      rest=''${*:2}
      case "$kind" in
        IDLE) printf 'ポモドーロ\n' ;;
        READY_WORK) printf 'Work! %s\n' "$rest" ;;
        READY_BREAK) printf 'Break! %s\n' "$rest" ;;
        DONE) printf 'Done! %s\n' "$rest" ;;
        *) printf '%s\n' "$state" ;;
      esac
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
          CTRL = '/tmp/pomo-ctrl'
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

              g.attach(Gtk.Label(label="Sessions:", xalign=0.0), 0, 2, 1, 1)
              self.ss = Gtk.SpinButton.new_with_range(1, 20, 1)
              self.ss.set_value(4)
              g.attach(self.ss, 1, 2, 1, 1)

              box.pack_start(Gtk.Separator(), False, False, 0)
              bb = Gtk.Box(spacing=6, homogeneous=True)
              self.start_btn = Gtk.Button(label="Start")
              self.start_btn.connect("clicked", self.start)
              self.stop_btn = Gtk.Button(label="Stop")
              self.stop_btn.connect("clicked", self.stop)
              self.next_btn = Gtk.Button(label="Next")
              self.next_btn.connect("clicked", self.next_session)
              bb.pack_start(self.start_btn, True, True, 0)
              bb.pack_start(self.stop_btn, True, True, 0)
              bb.pack_start(self.next_btn, True, True, 0)
              box.pack_start(bb, False, False, 0)

              GLib.timeout_add(500, self.tick)
              self.tick()

            def read_state(self):
              try: return open(STATE).read().strip()
              except Exception: return "IDLE"

            def parse_session(self, parts):
              if parts and "/" in parts[-1]:
                try:
                  c, t = parts[-1].split("/")
                  return int(c), int(t), parts[-1]
                except Exception:
                  pass
              return None, None, ""

            def tick(self):
              parts = self.read_state().split()
              kind = parts[0] if parts else "IDLE"
              cur, total, sess = self.parse_session(parts)
              suffix = " (" + sess + ")" if sess else ""

              if kind == "WORK" and len(parts) >= 3:
                display = "WORK " + parts[1] + suffix
              elif kind == "BREAK" and len(parts) >= 3:
                display = "BREAK " + parts[1] + suffix
              elif kind == "READY_BREAK":
                display = "Break Ready!" + suffix
              elif kind == "READY_WORK":
                display = "Work Ready!" + suffix
              elif kind == "DONE":
                display = "All Done!" + suffix
              else:
                display = "Idle"

              self.lbl.set_text(display)
              running = kind in ("WORK", "BREAK") and len(parts) >= 3
              ready = kind in ("READY_WORK", "READY_BREAK")
              self.start_btn.set_sensitive(not running)
              self.stop_btn.set_sensitive(running or ready)
              self.next_btn.set_sensitive(ready)
              return True

            def stop_daemon(self):
              try:
                with open(CTRL, 'w') as f: f.write("stop")
              except Exception: pass
              subprocess.run(['pkill', '-KILL', '-f', 'bin/pomo-daemon'], check=False)

            def _spawn_daemon(self, phase, mins, cur, total):
              self.stop_daemon()
              def go():
                subprocess.Popen(
                  [DAEMON, phase, str(mins), str(cur), str(total)],
                  stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                return False
              GLib.timeout_add(300, go)

            def start(self, _):
              total = int(self.ss.get_value())
              self._spawn_daemon("WORK", int(self.ws.get_value()), 1, total)

            def next_session(self, _):
              parts = self.read_state().split()
              cur, total, _ = self.parse_session(parts)
              if cur is None: return
              kind = parts[0]
              if kind == "READY_BREAK":
                self._spawn_daemon("BREAK", int(self.bs.get_value()), cur, total)
              elif kind == "READY_WORK":
                self._spawn_daemon("WORK", int(self.ws.get_value()), cur, total)

            def stop(self, _):
              self.stop_daemon()
              with open(STATE, 'w') as f: f.write("IDLE\n")

          GLib.set_prgname("pomodoro-popup")
          GLib.set_application_name("Pomodoro")
          w = Win()
          w._enters = 0
          def on_enter(*_):
            w._enters += 1
            return False
          def on_focus_out(*_):
            if w._enters >= 2:
              w.destroy()
            return False
          w.add_events(Gdk.EventMask.ENTER_NOTIFY_MASK)
          w.connect("enter-notify-event", on_enter)
          w.connect("destroy", Gtk.main_quit)
          w.connect("focus-out-event", on_focus_out)
          w.show_all()
          Gtk.main()
        '';
      };
    in pkgs.writeShellApplication {
      name = "pomo-popup";
      runtimeInputs = with pkgs; [ procps ];
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

  spicePkgs = spicetify-nix.legacyPackages.${pkgs.system};

in
{
  imports = [ spicetify-nix.homeManagerModules.default ];

  programs.spicetify = {
    enable = true;
    theme = spicePkgs.themes.comfy;
    colorScheme = "Everforest";
    enabledExtensions = with spicePkgs.extensions; [
      shuffle
      hidePodcasts
      fullAppDisplay
      {
        src = "${pkgs.fetchFromGitHub {
          owner = "rxri";
          repo = "spicetify-extensions";
          rev = "5da6cf1bb723f9efd0177f5fa4f4673b9e0c0936";
          hash = "sha256-8sx98scFd3C/n9KqpHPVf8/F6UX9lB9t23QMenJtZcM=";
        }}/adblock";
        name = "adblock.js";
      }
      {
        src = pkgs.writeTextDir "solid-scrubbar.js" ''
          (function solidScrubbar() {
            const style = document.createElement('style');
            style.id = 'solid-scrubbar-style';
            style.textContent = `
              .playback-progressbar-fg,
              .progress-bar-fg,
              .progress-bar__fg,
              .x-progressBar-fillForeground {
                background: var(--spice-text) !important;
                background-image: none !important;
                box-shadow: none !important;
                filter: none !important;
              }
              .playback-progressbar-bg,
              .progress-bar-bg {
                background: rgba(255,255,255,0.15) !important;
                filter: none !important;
              }
              .playback-progressbar__slider,
              .progress-bar__slider,
              .x-progressBar-sliderHandle {
                display: block !important;
                opacity: 1 !important;
                visibility: visible !important;
                width: 12px !important;
                height: 12px !important;
                background: var(--spice-text) !important;
                border-radius: 50% !important;
                border: none !important;
                box-shadow: 0 1px 3px rgba(0,0,0,0.4) !important;
              }
            `;
            document.head.appendChild(style);
          })();
        '';
        name = "solid-scrubbar.js";
      }
    ];
  };

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

  # Starship prompt — Gruvbox Material palette, git-aware
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$character";

      character = {
        success_symbol = "[❯](bold #a9b665)";
        error_symbol = "[❯](bold #ea6962)";
      };

      directory = {
        style = "bold #7daea3";
        truncation_length = 3;
        truncate_to_repo = true;
      };

      git_branch = {
        symbol = " ";
        style = "bold #d8a657";
        format = "on [$symbol$branch]($style) ";
      };

      git_status = {
        style = "#e78a4e";
        format = "([\\[$all_status$ahead_behind\\]]($style) )";
        conflicted = "=";
        ahead = "⇡$count";
        behind = "⇣$count";
        diverged = "⇕⇡$ahead_count⇣$behind_count";
        untracked = "?";
        stashed = "\\$";
        modified = "!";
        staged = "+";
        renamed = "»";
        deleted = "✘";
      };
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
        padding: 1px 10px;
        margin: 3px 4px;
        color: #000000;
        background: #c0c0c0;
        border: 1px solid #404040;
        box-shadow: inset 1px 1px 0 #ffffff, inset -1px -1px 0 #808080;
        min-width: 130px;
      }
      #custom-pomodoro:hover {
        background: #d0d0d0;
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
        "size 300 275, class:^(pomodoro-popup)$"
        "move cursor -150 0, class:^(pomodoro-popup)$"
        "animation slide, class:^(pomodoro-popup)$"
      ];

      exec-once = [
        "waybar"
        "kitty"
      ];
    };
  };

  programs.home-manager.enable = true;
}
