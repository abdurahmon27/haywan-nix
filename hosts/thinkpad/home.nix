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
      # browsers/chat bundles are all-or-nothing (Chrome+Firefox, Telegram+Discord),
      # so only the halves I actually use are listed in home.packages below.
      browsers.enable = false;
      chat.enable = false;

      editors.enable = true; # VS Code
      cli.enable = true; # btop, ripgrep, fd, jq, tree, unzip, fastfetch
      dev.enable = true; # Node 22 + yarn/pnpm, Python, Go, watchman, Claude Code

      cloud.enable = false; # gcloud + Compass — not needed yet
      media.enable = false; # VLC/mpv/ffmpeg — not needed yet
      fun.enable = false;
    };

    desktop = {
      browser = "google-chrome-stable";
      monitors = [ "eDP-1, preferred, 0x0, 1" ];
      wallpapers.dir = "/home/haywan/Pictures/wallpapers";
    };
  };

  home.packages = with pkgs; [
    google-chrome
    telegram-desktop
  ];

  programs.zsh.initContent = ''
    # T3 Code — drop the AppImage at ~/Applications/T3-Code.AppImage
    alias t3app='appimage-run "$HOME/Applications/T3-Code.AppImage" --no-sandbox'
  '';
}
