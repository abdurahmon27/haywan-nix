# Hyprland look & feel: keybinds, Waybar, Rofi, Kitty, Dunst, wallpapers.
# Plain config files live in ../../dotfiles — edit them there, then rebuild.
{ config, lib, pkgs, osConfig, ... }:

let
  cfg = config.haywan.desktop;
  dotfiles = ../../dotfiles;

  menu = "rofi -show drun -theme ~/.config/rofi/launcher.rasi";

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
    runtimeInputs = with pkgs; [ coreutils gnugrep jq ];
    text = builtins.readFile (dotfiles + "/waybar/phrases.sh");
  };

  phrasesFile =
    if cfg.phrases.file != null
    then cfg.phrases.file
    else "${pkgs.writeText "phrases.txt" (lib.concatLines cfg.phrases.items)}";

  # After a log out / log in the previous session's portal keeps running with a dead
  # display, and GTK apps (Waybar included) hang ~25 s waiting on it. Restart it first.
  resetPortals = pkgs.writeShellScript "reset-portals" ''
    ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd \
      WAYLAND_DISPLAY XDG_CURRENT_DESKTOP DISPLAY HYPRLAND_INSTANCE_SIGNATURE
    ${pkgs.systemd}/bin/systemctl --user stop xdg-desktop-portal-gtk xdg-desktop-portal-hyprland
    ${pkgs.systemd}/bin/systemctl --user restart xdg-desktop-portal
  '';

  autostart =
    [ "${resetPortals}; waybar" "nm-applet --indicator" ]
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
      pattern = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = ''(?<=Say ")[^"]*'';
        description = "Perl regex to extract phrases from `file` when it isn't one-per-line.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.wallpapers.dir != null) wallpaperNext;

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
            interval = 900;
            tooltip = true;
          };
        };

        right = {
          layer = "top";
          position = "right";
          width = 52;
          modules-left = [ "clock" ];
          modules-center = [ ];
          modules-right = [ "backlight" "wireplumber" "bluetooth" "network" "cpu" "memory" "temperature" "battery" "tray" ];

          clock = {
            format = "{:%H\n•\n%M}";
            format-alt = "{:%m\n•\n%d}";
            tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
          };
          wireplumber = {
            tooltip = true;
            tooltip-format = "Volume: {volume}%";
            scroll-step = 5;
            format = "{icon}";
            format-muted = "󰝟";
            on-click = "pavucontrol";
            format-icons = {
              default = [ "󰕿" "󰖀" "󰕾" ];
              headphone = "󰋋";
              headset = "󰋎";
            };
          };
          bluetooth = {
            format = "󰂲";
            format-on = "󰂯";
            format-connected = "󰂱";
            format-disabled = "󰂲";
            tooltip-format = "{controller_alias}\t{controller_address}";
            tooltip-format-connected = "{controller_alias}\t{controller_address}\n\n{device_enumerate}";
            tooltip-format-enumerate-connected = "{device_alias}\t{device_address}";
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
    services.dunst = {
      enable = true;
      settings.global = {
        font = "JetBrainsMono Nerd Font 11";
        corner_radius = 10;
        frame_width = 1;
        frame_color = "#504945";
        background = "#32302f";
        foreground = "#d4be98";
        offset = "16x16";
      };
    };
  };
}
