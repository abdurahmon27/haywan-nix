# zsh + Oh My Zsh + Powerlevel10k.
{ config, lib, pkgs, ... }:

let
  cfg = config.haywan.shell;
in
{
  options.haywan.shell = {
    enable = lib.mkEnableOption "zsh with Oh My Zsh and Powerlevel10k";
    p10kConfig = lib.mkOption {
      type = lib.types.path;
      default = ../../dotfiles/zsh/p10k.zsh;
      description = "Powerlevel10k config. Run `p10k configure` and copy ~/.p10k.zsh here to make your own.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      # Oh My Zsh runs compinit; syntax highlighting & autosuggestions come from the system zsh.
      enableCompletion = false;

      # Same history behaviour as a stock Oh My Zsh install.
      history = {
        size = 50000;
        save = 10000;
        extended = true;
        expireDuplicatesFirst = true;
      };

      oh-my-zsh = {
        enable = true;
        plugins = [ "git" "z" "sudo" ];
      };

      plugins = [
        {
          name = "powerlevel10k";
          src = pkgs.zsh-powerlevel10k;
          file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
        }
      ];

      initContent = lib.mkMerge [
        # Instant prompt must run before anything that may print or ask for input.
        (lib.mkBefore ''
          if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
            source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
          fi
        '')
        ''
          [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
          export PATH="$HOME/.local/bin:$PATH"
        ''
      ];
    };

    home.file.".p10k.zsh".source = cfg.p10kConfig;
  };
}
