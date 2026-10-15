{ osConfig, ... }:

{
  imports = [
    ./shell.nix
    ./git.nix
    ./apps.nix
    ./desktop.nix
    ./theme.nix
    ./obs.nix
    ./claude-limits.nix
  ];

  home.stateVersion = osConfig.system.stateVersion;
  programs.home-manager.enable = true;
}
