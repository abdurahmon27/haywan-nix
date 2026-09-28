{ config, lib, pkgs, ... }:

let
  cfg = config.haywan.git;
  ghHelper = [ "" "!${pkgs.gh}/bin/gh auth git-credential" ];
in
{
  options.haywan.git = {
    enable = lib.mkEnableOption "git + GitHub CLI (run `gh auth login` once for HTTPS auth)";
    name = lib.mkOption { type = lib.types.str; };
    email = lib.mkOption { type = lib.types.str; };
  };

  config = lib.mkIf cfg.enable {
    # gh is installed as a plain package so ~/.config/gh stays writable.
    home.packages = [ pkgs.gh ];

    programs.git = {
      enable = true;
      userName = cfg.name;
      userEmail = cfg.email;
      extraConfig = {
        init.defaultBranch = "main";
        credential."https://github.com".helper = ghHelper;
        credential."https://gist.github.com".helper = ghHelper;
      };
    };
  };
}
