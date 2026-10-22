{ pkgs, ... }:

let
  # T3 Code ships only as an AppImage (github.com/pingdotgg/t3code).
  # wrapType2 unpacks it into an FHS env, so it runs as a normal installed app
  # instead of needing appimage-run by hand.
  t3-code =
    let
      pname = "t3-code";
      version = "0.0.46-nightly.20261015.3145";
      src = pkgs.fetchurl {
        url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-x86_64.AppImage";
        hash = "sha256-S2hDSJ3yXzEwWokhFZsTBklvwQ8+0XKFvNvtj8a6kiM=";
      };
      contents = pkgs.appimageTools.extractType2 { inherit pname version src; };
    in
    pkgs.appimageTools.wrapType2 {
      inherit pname version src;

      # Ship the icon and menu entry too, so it shows up in Rofi.
      # The bundled Exec is "AppRun --no-sandbox %U"; point it at the wrapper.
      extraInstallCommands = ''
        install -Dm444 ${contents}/t3code.desktop \
          $out/share/applications/${pname}.desktop
        substituteInPlace $out/share/applications/${pname}.desktop \
          --replace-fail 'Exec=AppRun' 'Exec=${pname}'
        cp -r ${contents}/usr/share/icons $out/share/
      '';
    };
in
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
      wallpapers.dir = "/home/haywan/Wallpapers/gruvbox";

      # My dhikrs, pulled hourly from the Telegram bot on contabo.
      phrases = {
        enable = true;
        remote = "contabo:/home/deploy/faithful/src/dhikrs.js";
        pattern = ''(?<=Say ")[^"]*'';
      };
    };

    # Both Claude accounts in the bar, and a hook that holds non-urgent prompts near the limit.
    claudeLimits = {
      enable = true;
      accounts = [
        { name = "personal"; configDir = ".claude"; label = "󰚩"; }
        { name = "dona"; configDir = ".config/claude-dona"; label = "D"; }
      ];
    };
  };

  home.packages = [
    pkgs.google-chrome
    pkgs.telegram-desktop
    t3-code
  ];
}
