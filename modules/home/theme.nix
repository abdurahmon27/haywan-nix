# GTK look: Gruvbox dark, Gruvbox Plus icons, Bibata cursor, and a see-through
# libadwaita palette so Hyprland's blur shows behind Nautilus & co.
{ config, lib, pkgs, ... }:

let
  dotfiles = ../../dotfiles;
in
{
  config = lib.mkIf config.haywan.desktop.enable {
    gtk = {
      enable = true;
      colorScheme = "dark"; # libadwaita apps read this from dconf

      # GTK 3 apps only — libadwaita (GTK 4) ignores themes and gets the CSS below.
      theme = {
        package = pkgs.gruvbox-gtk-theme;
        name = "Gruvbox-Dark";
      };
      iconTheme = {
        package = pkgs.gruvbox-plus-icons;
        name = "Gruvbox-Plus-Dark";
      };
      cursorTheme = {
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Classic";
        size = 24;
      };
      font = {
        name = "JetBrainsMono Nerd Font";
        size = 11;
      };

      gtk4.theme = null; # Gruvbox-Dark would fight the libadwaita palette below
      gtk4.extraCss = builtins.readFile (dotfiles + "/gtk/gtk4.css");
    };

    # Same pointer in Hyprland and X apps.
    home.pointerCursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
      gtk.enable = true;
    };
  };
}
