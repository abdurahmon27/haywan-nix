# App bundles — turn on the ones you want in your host's home.nix:
#   haywan.apps.browsers.enable = true;
{ config, lib, pkgs, ... }:

let
  bundles = with pkgs; {
    browsers = {
      description = "Google Chrome and Firefox";
      packages = [ google-chrome firefox ];
    };
    chat = {
      description = "Telegram and Discord";
      packages = [ telegram-desktop discord-ptb ];
    };
    editors = {
      description = "Visual Studio Code";
      packages = [ vscode ];
    };
    cli = {
      description = "everyday terminal tools (btop, ripgrep, fd, jq, fastfetch…)";
      packages = [ btop ripgrep fd jq tree unzip fastfetch ];
    };
    dev = {
      description = "Node.js 22 (npm, yarn, pnpm), Python, Go, watchman and Claude Code";
      packages = [
        nodejs_22
        yarn
        pnpm
        python3
        go
        watchman
        claude-code
      ];
    };
    cloud = {
      description = "Google Cloud SDK and MongoDB Compass";
      packages = [ google-cloud-sdk mongodb-compass ];
    };
    media = {
      description = "VLC, mpv and ffmpeg";
      packages = [ vlc mpv ffmpeg ];
    };
    fun = {
      description = "cava, cmatrix, asciiquarium, nyancat";
      packages = [ cava cmatrix asciiquarium nyancat ];
    };
  };

  cfg = config.haywan.apps;
in
{
  options.haywan.apps = lib.mapAttrs
    (name: bundle: {
      enable = lib.mkEnableOption bundle.description;
    })
    bundles;

  config.home.packages = lib.concatLists (lib.mapAttrsToList
    (name: bundle: lib.optionals cfg.${name}.enable bundle.packages)
    bundles);
}
