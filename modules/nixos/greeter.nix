# Login screen (greetd). ReGreet is a graphical greeter running in the `cage` kiosk;
# tuigreet is the text-only fallback.
{ config, lib, pkgs, ... }:

let
  cfg = config.haywan.desktop;

  # Soft Gruvbox glow, rendered at build time so no wallpaper has to ship with the repo.
  defaultBackground = pkgs.runCommand "greeter-background.jpg"
    { nativeBuildInputs = [ pkgs.imagemagick ]; }
    ''
      magick -size 2560x1440 radial-gradient:'#504945'-'#1d2021' \
        \( -size 2560x1440 gradient:'#d65d0e'-'#1d2021' -rotate 180 -alpha set -channel A -evaluate set 12% \) \
        -compose over -composite -attenuate 0.35 +noise Uniform -blur 0x0.6 -quality 90 jpg:$out
    '';

  regreetCommand = lib.concatStringsSep " " (
    # NVIDIA's proprietary driver can't draw wlroots hardware cursors.
    lib.optional (config.haywan.hardware.gpu == "nvidia") "env WLR_NO_HARDWARE_CURSORS=1"
    ++ [
      "${pkgs.dbus}/bin/dbus-run-session"
      (lib.getExe pkgs.cage)
      (lib.escapeShellArgs config.programs.regreet.cageArgs)
      "--"
      (lib.getExe config.programs.regreet.package)
    ]
  );
in
{
  options.haywan.desktop = {
    greeter = lib.mkOption {
      type = lib.types.enum [ "regreet" "tuigreet" ];
      default = "regreet";
      description = "`regreet` is graphical, `tuigreet` is text-only.";
    };

    greeterBackground = lib.mkOption {
      type = lib.types.path;
      default = defaultBackground;
      description = "Login screen background image. It's copied into the Nix store, so it must live inside your flake.";
    };

    autoLogin = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Skip the password prompt and start Hyprland right away.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      services.greetd = {
        enable = true;
        settings.initial_session = lib.mkIf cfg.autoLogin {
          command = "Hyprland";
          user = config.haywan.user.name;
        };
      };
    }

    (lib.mkIf (cfg.greeter == "tuigreet") {
      services.greetd.settings.default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --cmd Hyprland";
        user = lib.mkDefault "greeter";
      };
    })

    (lib.mkIf (cfg.greeter == "regreet") {
      programs.regreet = {
        enable = true;
        # Show it on the most recently connected monitor (the external one when docked).
        cageArgs = [ "-s" "-m" "last" ];

        theme = {
          package = pkgs.gruvbox-gtk-theme;
          name = "Gruvbox-Dark";
        };
        iconTheme = {
          package = pkgs.papirus-icon-theme;
          name = "Papirus-Dark";
        };
        cursorTheme = {
          package = pkgs.bibata-cursors;
          name = "Bibata-Modern-Ice";
        };
        font = {
          package = pkgs.nerd-fonts.jetbrains-mono;
          name = "JetBrainsMono Nerd Font";
          size = 13;
        };

        settings = {
          background = {
            path = "${cfg.greeterBackground}";
            fit = "Cover";
          };
          GTK.application_prefer_dark_theme = true;
          appearance.greeting_msg = "Welcome back";
          widget.clock = {
            format = "%A, %d %B   %H:%M";
            resolution = "1s";
            label_width = 360;
          };
        };

        extraCss = ../../dotfiles/regreet/style.css;
      };

      services.greetd.settings.default_session = {
        command = regreetCommand;
        user = lib.mkDefault "greeter";
      };

      # Preselect the main user and Hyprland on the very first boot. Only copied when
      # the file doesn't exist yet; afterwards ReGreet remembers the last choice itself.
      systemd.tmpfiles.settings."11-regreet-state"."/var/lib/regreet/state.toml" =
        let
          owner = {
            user = config.services.greetd.settings.default_session.user;
            group = "greeter";
          };
        in
        {
          C = owner // {
            argument = "${pkgs.writeText "regreet-state.toml" ''
              last_user = "${config.haywan.user.name}"

              [user_to_last_sess]
              ${config.haywan.user.name} = "Hyprland"
            ''}";
          };
          z = owner // { mode = "0644"; };
        };
    })
  ]);
}
