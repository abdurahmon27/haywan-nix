{ config, lib, pkgs, ... }:

let
  # Howdy refuses v4l2loopback in boot.kernelModules (it stops finding the IR camera).
  loadAtBoot = !config.haywan.hardware.faceUnlock.enable;
in
{
  options.haywan.media.obs.enable = lib.mkEnableOption "OBS Studio with a virtual camera (/dev/video*)";

  config = lib.mkIf config.haywan.media.obs.enable (lib.mkMerge [
    {
      # Must be the NixOS module (not a plain package) so v4l2loopback gets loaded.
      programs.obs-studio = {
        enable = true;
        enableVirtualCamera = loadAtBoot;
        plugins = with pkgs.obs-studio-plugins; [ obs-vkcapture ];
      };
    }

    # The virtual camera module minus the boot-time load. "Start Virtual Camera"
    # then runs `pkexec modprobe v4l2loopback` itself (one admin prompt per boot).
    (lib.mkIf (!loadAtBoot) {
      boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
      boot.extraModprobeConfig = ''
        options v4l2loopback devices=1 video_nr=1 card_label="OBS Cam" exclusive_caps=1
      '';
      security.polkit.enable = true;
    })
  ]);
}
