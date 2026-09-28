{ config, lib, pkgs, ... }:

{
  options.haywan.media.obs.enable = lib.mkEnableOption "OBS Studio with a virtual camera (/dev/video*)";

  config = lib.mkIf config.haywan.media.obs.enable {
    # Must be the NixOS module (not a plain package) so v4l2loopback gets loaded.
    programs.obs-studio = {
      enable = true;
      enableVirtualCamera = true;
      plugins = with pkgs.obs-studio-plugins; [ obs-vkcapture ];
    };
  };
}
