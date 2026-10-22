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
      description = "everyday terminal tools (btop, ripgrep, fd, jq, fzf, zoxide, eza, bat, lazygit, delta…)";
      packages = [ ripgrep fd jq tree unzip fastfetch lazydocker ];
    };
    dev = {
      description = "Node.js 24 (npm, yarn, pnpm), Python + uv, Go + gopls, direnv, pgcli, watchman and Claude Code";
      packages = [
        nodejs_24
        yarn
        pnpm
        python3
        uv # pip/venv/pyenv in one; prebuilt Pythons run thanks to nix-ld
        go
        gopls
        golangci-lint
        pgcli
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

  config = {
    home.packages = lib.concatLists (lib.mapAttrsToList
      (name: bundle: lib.optionals cfg.${name}.enable bundle.packages)
      bundles);

    # btop in the same Gruvbox Material palette as kitty and Waybar.
    programs.btop = lib.mkIf cfg.cli.enable {
      enable = true;
      themes.gruvbox-material = ../../dotfiles/btop/gruvbox-material.theme;
      settings = {
        color_theme = "gruvbox-material";
        theme_background = false; # let kitty's background show
        rounded_corners = true;
        vim_keys = true;
        update_ms = 1000;
      };
    };

    # Ctrl+R / Ctrl+T fuzzy search; `z <dir>` jumps (zoxide replaces Oh My Zsh's z);
    # ls/ll/lt are eza with icons and git status.
    programs.fzf.enable = cfg.cli.enable;
    programs.zoxide.enable = cfg.cli.enable;
    programs.eza = lib.mkIf cfg.cli.enable {
      enable = true;
      icons = "auto";
      git = true;
    };
    programs.bat = lib.mkIf cfg.cli.enable {
      enable = true;
      config.theme = "gruvbox-dark";
    };
    programs.lazygit.enable = cfg.cli.enable;
    # Side-by-side, highlighted diffs in git diff/log/show (and in lazygit).
    programs.delta = lib.mkIf cfg.cli.enable {
      enable = true;
      enableGitIntegration = true;
      options = {
        navigate = true;
        line-numbers = true;
        syntax-theme = "gruvbox-dark";
      };
    };

    # Per-project toolchains: a project's .envrc loads its dev shell on `cd`.
    # nix-direnv caches it, so it's instant after the first time. See the README.
    programs.direnv = lib.mkIf cfg.dev.enable {
      enable = true;
      nix-direnv.enable = true;
      config.global.hide_env_diff = true;
    };
  };
}
