{ pkgs, ... }:

{
  haywan = {
    shell.enable = true;

    git = {
      enable = true;
      name = "abdurahmon27";
      email = "bekzotovich12@gmail.com";
    };

    apps = {
      browsers.enable = true;
      chat.enable = true;
      editors.enable = true;
      cli.enable = true;
      dev.enable = true;
      cloud.enable = true;
      media.enable = true;
      fun.enable = true;
    };

    desktop = {
      browser = "google-chrome-stable";
      monitors = [
        "eDP-1, 1920x1080@144, 0x0, 1" # laptop
        "DP-1, 1920x1080@75, 0x-1080, 1" # Xiaomi, above the laptop
      ];
      wallpapers.dir = "/home/haywan/Wallpapers/gruvbox-pixelart";

      # Mine are dhikrs, read from my Telegram bot's source (not part of this repo).
      phrases = {
        enable = true;
        file = "/home/haywan/Developer/faithful/src/dhikrs.js";
        pattern = ''(?<=Say ")[^"]*'';
      };
    };
  };

  programs.waybar.settings.right.temperature = {
    thermal-zone = 2;
    hwmon-path = "/sys/class/hwmon/hwmon2/temp1_input";
  };

  home.packages = with pkgs; [
    sublime
    anydesk
    neofetch
    clock-rs
    jp2a
    # other Wayland toys I play with
    eww
    alacritty
    wofi
    hyprpaper
    swaybg
    wpaperd
    mpvpaper
  ];

  programs.zsh.initContent = ''
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

    alias ship='~/ios-dev/ship'
    alias t3app='appimage-run "$HOME/Applications/T3-Code.AppImage" --no-sandbox'

    # Second Claude account in its own config dir.
    claude-dona() { CLAUDE_CONFIG_DIR="$HOME/.claude-dona" claude "$@"; }
  '';

  programs.git.includes = [
    {
      condition = "gitdir:~/Developer/ozb/";
      path = "~/Developer/ozb/.gitconfig";
    }
  ];
}
