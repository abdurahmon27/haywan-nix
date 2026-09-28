{ osConfig, ... }:

{
  imports = [
    ./shell.nix
    ./git.nix
    ./apps.nix
    ./desktop.nix
  ];

  home.stateVersion = osConfig.system.stateVersion;
  programs.home-manager.enable = true;
}
