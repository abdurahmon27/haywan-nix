# Hyprland desktop: compositor, portals, fonts, theme, core Wayland tools.
# Login screen: greeter.nix. Look & feel (keybinds, bar, terminal): modules/home/desktop.nix.
{ config, lib, pkgs, ... }:

let
  cfg = config.haywan.desktop;
in
{
  options.haywan.desktop = {
    enable = lib.mkEnableOption "the Hyprland desktop";

    keyboard = {
      layout = lib.mkOption {
        type = lib.types.str;
        default = "us";
        example = "us,ru";
      };
      options = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "grp:alt_shift_toggle";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };

    # X server is only kept for XWayland apps, xrdp and keyboard defaults.
    services.xserver = {
      enable = true;
      xkb = { inherit (cfg.keyboard) layout options; variant = ""; };
      displayManager.setupCommands = ''
        xset r rate 200 40
      '';
    };

    xdg.portal = {
      enable = true;
      xdgOpenUsePortal = true;
      extraPortals = with pkgs; [ xdg-desktop-portal-hyprland xdg-desktop-portal-gtk ];
    };

    services.gvfs.enable = true;
    services.tumbler.enable = true;

    fonts.packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-emoji
      font-awesome
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
    ];

    environment.systemPackages = with pkgs; [
      # bar, launcher, wallpaper, notifications
      waybar
      rofi-wayland
      swww
      dunst
      libnotify
      # terminal & files
      kitty
      ranger
      nautilus
      # screenshots & clipboard
      grim
      slurp
      wl-clipboard
      # controls
      networkmanagerapplet
      brightnessctl
      pavucontrol
      # theme
      bibata-cursors
      gruvbox-gtk-theme
      papirus-icon-theme
    ];

    environment.variables = {
      XKB_DEFAULT_LAYOUT = cfg.keyboard.layout;
      XKB_DEFAULT_OPTIONS = cfg.keyboard.options;
      XCURSOR_THEME = "Bibata-Modern-Ice";
      XCURSOR_SIZE = "24";
      GTK_THEME = "Gruvbox-Dark";
      XDG_CURRENT_DESKTOP = "Hyprland";
    };

    # Electron / Chromium apps run natively on Wayland.
    environment.sessionVariables.NIXOS_OZONE_WL = "1";
  };
}
