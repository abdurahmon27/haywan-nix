# Your user environment (Home Manager).
{ pkgs, ... }:

{
  haywan = {
    shell.enable = true; # zsh + Oh My Zsh + Powerlevel10k

    git = {
      enable = true;
      name = "Alice";
      email = "alice@example.com";
    };

    apps = {
      browsers.enable = true; # Chrome, Firefox
      chat.enable = true; # Telegram, Discord
      editors.enable = true; # VS Code
      cli.enable = true; # btop, ripgrep, fd, jq, fastfetch…
      dev.enable = false; # Node, Python, Go, Claude Code
      cloud.enable = false; # gcloud, MongoDB Compass
      media.enable = true; # VLC, mpv, ffmpeg
      fun.enable = false; # cava, cmatrix, nyancat…
    };

    desktop = {
      # `hyprctl monitors` lists your outputs.
      monitors = [ ", preferred, auto, 1" ];
      # wallpapers.dir = "/home/alice/Pictures/wallpapers";

      # A phrase in the top bar that changes every hour.
      phrases = {
        enable = true;
        items = [ "Stay curious" "Drink some water" "Ship it" ];
      };
    };
  };

  # Anything else from https://search.nixos.org/packages
  home.packages = with pkgs; [ ];
}
