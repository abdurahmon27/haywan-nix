# Hyprland look & feel: keybinds, Waybar, Rofi, Kitty, Dunst, wallpapers.
# Plain config files live in ../../dotfiles — edit them there, then rebuild.
{ config, lib, pkgs, osConfig, ... }:

let
  cfg = config.haywan.desktop;
  dotfiles = ../../dotfiles;

  # Toggles: run it again (click the cat, Super+Space) to close an open launcher.
  menu = "pkill -x rofi || rofi -show drun -theme ~/.config/rofi/launcher.rasi";

  # One shared FIFO: the loop waits on it instead of sleeping, so `wallpaper-next`
  # can cut a nap short and advance immediately.
  wallpaperFifo = "\${XDG_RUNTIME_DIR:-/tmp}/wallpaper-loop.fifo";

  wallpaperLoop = pkgs.writeShellApplication {
    name = "wallpaper-loop";
    runtimeInputs = with pkgs; [ awww coreutils findutils ];
    text = ''
      # Cycles the wallpapers in a folder, forever, with a different awww
      # animation every time.
      dir="$1"
      interval="$2"
      fifo="${wallpaperFifo}"

      # Ask the daemon directly -- its process name is the Nix wrapper's
      # (.awww-daemon-wr), so pgrep would miss it and we'd spawn a doomed second one.
      if ! awww query >/dev/null 2>&1; then
        awww-daemon &
        for _ in $(seq 1 50); do
          awww query >/dev/null 2>&1 && break
          sleep 0.1
        done
      fi

      mapfile -t images < <(find -L "$dir" -maxdepth 1 -type f \
        \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' \) | sort)
      if [ "''${#images[@]}" -eq 0 ]; then
        echo "wallpaper-loop: no images in $dir" >&2
        exit 1
      fi

      # Hold both ends open so `wallpaper-next` never blocks on an absent reader.
      rm -f "$fifo"
      mkfifo "$fifo"
      exec 3<>"$fifo"
      trap 'rm -f "$fifo"' EXIT

      transitions=(wipe wave grow outer center any left right top bottom fade)

      while true; do
        mapfile -t shuffled < <(printf '%s\n' "''${images[@]}" | shuf)
        for img in "''${shuffled[@]}"; do
          transition=$(printf '%s\n' "''${transitions[@]}" | shuf -n1)

          # wipe/wave sweep at this angle; grow/outer open from this point.
          angle=$((RANDOM % 360))
          pos="0.$(printf '%02d' $((RANDOM % 100))),0.$(printf '%02d' $((RANDOM % 100)))"

          # Nearest keeps pixel art crisp; everything else wants a smooth filter.
          case "$(basename "$img")" in
            pixel-*) filter=Nearest ;;
            *)       filter=Lanczos3 ;;
          esac

          awww img "$img" \
            --transition-type "$transition" \
            --transition-duration 2 \
            --transition-fps 60 \
            --transition-step 90 \
            --transition-angle "$angle" \
            --transition-pos "$pos" \
            --transition-bezier .25,.1,.25,1 \
            --resize crop \
            --filter "$filter" \
            --fill-color 1d2021

          # Wake early if someone pressed the "next wallpaper" bind, then swallow
          # any extra presses that piled up during the animation.
          if read -r -t "$interval" -u 3 _; then
            while read -r -t 0 -u 3 _; do :; done
          fi
        done
      done
    '';
  };

  wallpaperNext = pkgs.writeShellApplication {
    name = "wallpaper-next";
    runtimeInputs = with pkgs; [ coreutils ];
    text = ''
      fifo="${wallpaperFifo}"
      if [ ! -p "$fifo" ]; then
        echo "wallpaper-next: no wallpaper-loop running" >&2
        exit 1
      fi
      printf 'next\n' > "$fifo"
    '';
  };

  phrasesScript = pkgs.writeShellApplication {
    name = "waybar-phrases";
    runtimeInputs = with pkgs; [ coreutils gnugrep jq procps ];
    text = builtins.readFile (dotfiles + "/waybar/phrases.sh");
  };

  notificationsScript = pkgs.writeShellApplication {
    name = "waybar-notifications";
    runtimeInputs = with pkgs; [ jq swaynotificationcenter util-linux ];
    text = builtins.readFile (dotfiles + "/waybar/notifications.sh");
  };

  bluetoothScript = pkgs.writeShellApplication {
    name = "waybar-bluetooth";
    runtimeInputs = with pkgs; [ bluez gawk jq ];
    text = builtins.readFile (dotfiles + "/waybar/bluetooth.sh");
  };

  phrasesFile =
    if cfg.phrases.file != null
    then cfg.phrases.file
    else if cfg.phrases.remote != null
    then "${config.xdg.cacheHome}/waybar-phrases"
    else "${pkgs.writeText "phrases.txt" (lib.concatLines cfg.phrases.items)}";

  # After a log out / log in the previous session's portal keeps running with a dead
  # display, and GTK apps (Waybar included) hang ~25 s waiting on it. Restart it first.
  resetPortals = pkgs.writeShellScript "reset-portals" ''
    ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd \
      WAYLAND_DISPLAY XDG_CURRENT_DESKTOP DISPLAY HYPRLAND_INSTANCE_SIGNATURE
    ${pkgs.systemd}/bin/systemctl --user stop xdg-desktop-portal-gtk xdg-desktop-portal-hyprland
    ${pkgs.systemd}/bin/systemctl --user restart xdg-desktop-portal
  '';

  # Big block-digit clock for the lock screen, in the style of clock-rs / tty-clock.
  # hyprlock re-runs it every second and draws its output as a label.
  lockClock = pkgs.writeShellScript "lock-clock" ''
    # Each digit is 3 cells wide and 5 tall, read row by row; 1 = lit.
    font=(111101101101111 001001001001001 111001111100111 111001111001111 101101111001001
          111100111001111 111100111101111 111001001001001 111101111101111 111101111001111)
    # Unlit cells are drawn faint rather than as spaces: hyprlock centers every line
    # on its own and trims blanks, which would shear the digits apart.
    on='██'; off='<span fgalpha="7%">██</span>'
    t=$(${pkgs.coreutils}/bin/date +%H%M)
    out=""
    for row in 0 1 2 3 4; do
      line=""
      for i in 0 1 2 3; do
        bits=''${font[''${t:i:1}]:row*3:3}
        for b in 0 1 2; do
          [ "''${bits:b:1}" = 1 ] && line+="$on" || line+="$off"
        done
        case $i in
          1) { [ "$row" = 1 ] || [ "$row" = 3 ]; } && line+="  $on  " || line+="      " ;;
          3) ;;
          *) line+="  " ;;
        esac
      done
      out+="$line"$'\n'
    done
    # Tighter spacing closes the seams between the block glyphs.
    printf '<span letter_spacing="-600" line_height="0.85">%s</span>' "''${out%$'\n'}"
  '';

  autostart =
    # Auto-login boots straight into Hyprland, so lock before anything else shows.
    lib.optional (osConfig.haywan.desktop.autoLogin or false) "hyprlock --immediate-render --no-fade-in"
    ++ lib.optional (cfg.lock.idleMinutes != null) (lib.getExe pkgs.hypridle)
    ++ [ "${resetPortals}; waybar" "nm-applet --indicator" ]
    # Polkit agent: without one, anything asking polkit for a password or a
    # fingerprint (fprintd-enroll, GUI admin prompts) is denied outright.
    ++ [ "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent" ]
    ++ lib.optional (cfg.wallpapers.dir != null)
      "${lib.getExe wallpaperLoop} ${cfg.wallpapers.dir} ${toString cfg.wallpapers.interval}"
    ++ lib.optional (osConfig.haywan.remote.vnc.enable or false)
      # Listens on all interfaces, but the firewall only opens 5900 on tailscale0.
      "wayvnc 0.0.0.0 5900"
    ++ cfg.autostart;
in
{
  options.haywan.desktop = {
    enable = lib.mkEnableOption "the Hyprland dotfiles" // {
      default = osConfig.haywan.desktop.enable or false;
    };

    monitors = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ", preferred, auto, 1" ];
      example = [ "eDP-1, 1920x1080@144, 0x0, 1" "DP-1, 1920x1080@75, 0x-1080, 1" ];
      description = "Hyprland `monitor =` lines. Run `hyprctl monitors` to see names.";
    };

    terminal = lib.mkOption { type = lib.types.str; default = "kitty"; };
    browser = lib.mkOption { type = lib.types.str; default = "firefox"; };
    fileManager = lib.mkOption { type = lib.types.str; default = "kitty -- ranger"; };

    autostart = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra commands to run when Hyprland starts.";
    };

    lock.idleMinutes = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = 5;
      description = "Lock after this many idle minutes (dims 30 s before, screen off at twice that). null = only Super+Escape.";
    };

    wallpapers = {
      dir = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/home/alice/Wallpapers";
        description = "Folder of images to cycle through. null = Hyprland's default wallpaper.";
      };
      interval = lib.mkOption {
        type = lib.types.int;
        default = 300;
        description = "Seconds each wallpaper stays up.";
      };
    };

    phrases = {
      enable = lib.mkEnableOption "a Waybar module that shows a different phrase every hour";
      items = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "Stay curious" "Drink some water" "Ship it" ];
        description = "The phrases to rotate through.";
      };
      file = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Read phrases from this file at runtime instead of `items` (one per line).";
      };
      remote = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "myserver:/srv/bot/phrases.txt";
        description = ''
          Fetch the phrases file with scp from this `host:path`, at login and every hour.
          Uses your ~/.ssh/config, so the key must work without a passphrase prompt.
        '';
      };
      pattern = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = ''(?<=Say ")[^"]*'';
        description = "Perl regex to extract phrases from `file` when it isn't one-per-line.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.gdu ] # the storage module opens it
      ++ lib.optional (cfg.wallpapers.dir != null) wallpaperNext;

    # Keeps a local copy of `phrases.remote`; the bar keeps the last copy while offline.
    systemd.user = lib.mkIf (cfg.phrases.enable && cfg.phrases.remote != null) {
      services.waybar-phrases-sync = {
        Unit.Description = "Fetch Waybar phrases from ${cfg.phrases.remote}";
        Service = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "waybar-phrases-sync" ''
            tmp="${phrasesFile}.part"
            ${pkgs.openssh}/bin/scp -q -o BatchMode=yes -o ConnectTimeout=15 \
              ${lib.escapeShellArg cfg.phrases.remote} "$tmp" && mv "$tmp" ${lib.escapeShellArg phrasesFile}
            ${pkgs.procps}/bin/pkill -RTMIN+8 waybar || true
          '';
        };
      };
      timers.waybar-phrases-sync = {
        Unit.Description = "Fetch Waybar phrases hourly";
        Timer = { OnStartupSec = "10s"; OnUnitActiveSec = "1h"; Persistent = true; };
        Install.WantedBy = [ "timers.target" ];
      };
    };

    # ── Hyprland ────────────────────────────────────────────────────────────
    xdg.configFile = {
      "hypr/hyprland.conf".text = ''
        # Generated by haywan-nix (modules/home/desktop.nix).

        ${lib.concatMapStrings (cmd: "exec-once = ${cmd}\n") autostart}
        source = ~/.config/hypr/modules/env.conf
        source = ~/.config/hypr/modules/monitors.conf
        source = ~/.config/hypr/modules/general.conf
        source = ~/.config/hypr/modules/input.conf
        source = ~/.config/hypr/modules/rules.conf
        source = ~/.config/hypr/modules/binds.conf
      '';

      "hypr/modules/env.conf".text = ''
        env = XCURSOR_SIZE,24
        env = XCURSOR_THEME,Bibata-Modern-Classic

        $terminal = ${cfg.terminal}
        $fileManager = ${cfg.fileManager}
        $menu = ${menu}
        $browser = ${cfg.browser}
        $wallpaperNext = ${lib.getExe wallpaperNext}
      '';

      "hypr/modules/monitors.conf".text =
        lib.concatMapStrings (m: "monitor = ${m}\n") cfg.monitors;

      "hypr/modules/general.conf".source = dotfiles + "/hypr/general.conf";
      "hypr/modules/input.conf".source = dotfiles + "/hypr/input.conf";
      "hypr/modules/rules.conf".source = dotfiles + "/hypr/rules.conf";
      "hypr/modules/binds.conf".source = dotfiles + "/hypr/binds.conf";

      # ── Lock screen ───────────────────────────────────────────────────────
      "hypr/hyprlock.conf".text = ''
        # Generated by haywan-nix (modules/home/desktop.nix); the look is dotfiles/hypr/hyprlock.conf.
        $clock = ${lockClock}

        auth {
          fingerprint:enabled = ${lib.boolToString (osConfig.haywan.hardware.fingerprint.enable or false)}
          fingerprint:ready_message = touch the sensor or type your password
          fingerprint:present_message = scanning…
        }

      '' + builtins.readFile (dotfiles + "/hypr/hyprlock.conf");

      "hypr/hypridle.conf" = lib.mkIf (cfg.lock.idleMinutes != null) {
        text =
          let secs = cfg.lock.idleMinutes * 60; in
          ''
            general {
              lock_cmd = pidof hyprlock || hyprlock
              before_sleep_cmd = loginctl lock-session
              after_sleep_cmd = hyprctl dispatch dpms on
            }

            listener {
              timeout = ${toString (secs - 30)}
              on-timeout = brightnessctl -s set 10%
              on-resume = brightnessctl -r
            }

            listener {
              timeout = ${toString secs}
              on-timeout = loginctl lock-session
            }

            listener {
              timeout = ${toString (secs * 2)}
              on-timeout = hyprctl dispatch dpms off
              on-resume = hyprctl dispatch dpms on && brightnessctl -r
            }
          '';
      };

      # ── Terminal & launcher ───────────────────────────────────────────────
      "kitty/kitty.conf".source = dotfiles + "/kitty/kitty.conf";
      "kitty/theme.conf".source = dotfiles + "/kitty/theme.conf";
      "rofi/launcher.rasi".source = dotfiles + "/rofi/launcher.rasi";
    };

    # ── Waybar: a thin top bar + a vertical bar on the right ────────────────
    programs.waybar = {
      enable = true;
      style = builtins.readFile (dotfiles + "/waybar/style.css");
      settings = {
        top = {
          layer = "top";
          position = "top";
          modules-left = [ "custom/launcher" "hyprland/workspaces" ];
          modules-center = [ ];
          modules-right = lib.optional cfg.phrases.enable "custom/phrases";

          "custom/launcher" = {
            format = "";
            on-click = menu;
            on-click-right = "pkill rofi";
            tooltip = false;
          };
          "hyprland/workspaces" = {
            format = "{id}";
            on-click = "activate";
            sort-by-number = true;
            persistent-workspaces."*" = 5;
          };
          "custom/phrases" = lib.mkIf cfg.phrases.enable {
            exec = lib.escapeShellArgs ([ (lib.getExe phrasesScript) phrasesFile ]
              ++ lib.optional (cfg.phrases.pattern != null) cfg.phrases.pattern);
            return-type = "json";
            # Cheap to run; checking every minute makes the hourly change land on the hour.
            interval = 60;
            signal = 8;
            on-click = "${lib.getExe phrasesScript} --next";
            tooltip = true;
          };
        };

        right = {
          layer = "top";
          position = "right";
          width = 52;
          modules-left = [ "clock" "custom/notifications" ];
          modules-center = [ ];
          modules-right = [ "backlight" "pulseaudio" "custom/bluetooth" "network" "cpu" "memory" "disk" "temperature" "battery" "tray" ];

          clock = {
            format = "{:%H\n•\n%M}";
            format-alt = "{:%m\n•\n%d}";
            tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
          };
          # Rings for a few seconds when something arrives; click for the panel.
          "custom/notifications" = {
            exec = lib.getExe notificationsScript;
            return-type = "json";
            restart-interval = 2;
            format = "{icon}";
            format-icons = {
              none = "󰂜";
              notification = "󱅫";
              dnd-none = "󰂛";
              dnd-notification = "󰂛";
              inhibited-none = "󰂜";
              inhibited-notification = "󱅫";
              dnd-inhibited-none = "󰂛";
              dnd-inhibited-notification = "󰂛";
            };
            tooltip = true;
            on-click = "swaync-client -t -sw";
            on-click-right = "swaync-client -d -sw";
            on-click-middle = "swaync-client -C -sw";
            escape = true;
          };
          # Volume always shows a speaker: the Bluetooth widget right below shows
          # the device. pulseaudio rather than wireplumber for {desc} (the output) in the tooltip.
          pulseaudio = {
            format = "{icon}\n<small>{volume}</small>";
            format-muted = "󰖁\n<small>--</small>";
            format-icons.default = [ "󰕿" "󰖀" "󰕾" ];
            justify = "center";
            tooltip-format = "{desc}\n{volume}%";
            scroll-step = 5;
            on-click = "pavucontrol";
            on-click-right = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
          };
          "custom/bluetooth" = {
            exec = lib.getExe bluetoothScript;
            return-type = "json";
            interval = 5;
            justify = "center";
            on-click = "blueman-manager";
          };
          network = {
            tooltip = true;
            tooltip-format-wifi = "{essid}\nSignal: {signalStrength}%\nIP: {ipaddr}";
            tooltip-format-ethernet = "{ifname}\nIP: {ipaddr}";
            tooltip-format-disconnected = "Disconnected";
            format-wifi = "{icon}";
            format-ethernet = "󰈀";
            format-disconnected = "󰤭";
            format-icons = [ "󰤯" "󰤟" "󰤢" "󰤥" "󰤨" ];
            on-click = "nm-connection-editor";
          };
          backlight = {
            tooltip = true;
            tooltip-format = "Brightness: {percent}%";
            format = "{icon}";
            format-icons = [ "󰃞" "󰃟" "󰃠" ];
            on-scroll-up = "brightnessctl set 5%+";
            on-scroll-down = "brightnessctl set 5%-";
          };
          battery = {
            states = { full = 100; good = 95; decent = 50; warning = 30; critical = 20; };
            format = "{icon}";
            format-charging = "󰂄";
            format-plugged = "󰂅";
            format-time = "{H}h {M}m";
            tooltip-format = "{capacity}% - {time}";
            format-icons = [ "󰂎" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
          };
          cpu = {
            interval = 5;
            format = "{icon}";
            format-icons = [ "󰪞" "󰪟" "󰪠" "󰪡" "󰪢" "󰪣" "󰪤" "󰪥" ];
            tooltip = true;
            tooltip-format = "CPU: {usage}%";
            on-click = "${cfg.terminal} -e btop";
          };
          memory = {
            interval = 10;
            format = "{icon}";
            format-icons = [ "󰪞" "󰪟" "󰪠" "󰪡" "󰪢" "󰪣" "󰪤" "󰪥" ];
            tooltip = true;
            tooltip-format = "RAM: {used:0.1f}G / {total:0.1f}G\nSwap: {swapUsed:0.1f}G / {swapTotal:0.1f}G";
          };
          # Free space on /, since that's the number to watch on a small SSD.
          disk = {
            path = "/";
            interval = 60;
            unit = "GiB";
            format = "󰋊\n<small>{specific_free:0.0f}G</small>";
            justify = "center";
            states = { warning = 80; critical = 90; };
            tooltip-format = "{used} used of {total}\n{free} free ({percentage_free}%)\n\nClick to see what's taking space";
            on-click = "${cfg.terminal} -e gdu ~";
          };
          temperature = {
            critical-threshold = 80;
            format = "{icon}";
            format-critical = "󰸁";
            format-icons = [ "󱃃" "󰔏" "󱃂" ];
            tooltip = true;
            tooltip-format = "{temperatureC}°C";
          };
          tray = {
            icon-size = 16;
            spacing = 4;
          };
        };
      };
    };

    # ── Notifications ───────────────────────────────────────────────────────
    # Small popups that leave quickly; everything stays in the panel (Super+N).
    services.swaync = {
      enable = true;
      settings = {
        positionX = "right";
        positionY = "top";
        notification-window-width = 340;
        control-center-width = 380;
        control-center-height = 560;
        control-center-margin-top = 8;
        control-center-margin-right = 8;
        control-center-margin-bottom = 8;
        timeout = 4;
        timeout-low = 2;
        timeout-critical = 0; # stays until dismissed
        notification-body-image-height = 80;
        notification-body-image-width = 160;
        hide-on-clear = true;
        widgets = [ "title" "dnd" "notifications" ];
        widget-config = {
          title = { text = "Notifications"; clear-all-button = true; button-text = "Clear"; };
          dnd.text = "Do not disturb";
        };
      };
      style = ''
        @import url("file://${pkgs.swaynotificationcenter}/etc/xdg/swaync/style.css");
      '' + builtins.readFile (dotfiles + "/swaync/style.css");
    };
  };
}
