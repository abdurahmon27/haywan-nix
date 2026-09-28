{ config, lib, pkgs, ... }:

{
  options.haywan.gaming.enable = lib.mkEnableOption "Steam, GameMode and MangoHud";

  config = lib.mkIf config.haywan.gaming.enable {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };
    programs.gamemode.enable = true;
    environment.systemPackages = with pkgs; [ mangohud vulkan-tools ];
  };
}
