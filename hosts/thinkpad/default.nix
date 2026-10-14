# haywan's ThinkPad — Intel i5-10210U, Intel UHD graphics, Hyprland.
# Lean on purpose: no Android SDK, no Steam, no OBS, no MongoDB — disk is tight.
{ ... }:

{
  imports = [ ./hardware-configuration.nix ];

  haywan = {
    user = {
      name = "haywan";
      description = "abdurahmon";
    };
    timeZone = "Asia/Tashkent";
    boot.loader = "systemd-boot"; # this install is EFI + systemd-boot

    hardware.gpu = "intel";

    desktop = {
      enable = true;
      keyboard.options = "altwin:super_win";
    };

    # Heavy extras, all off.
    gaming.enable = false;
    media.obs.enable = false;

    dev = {
      docker.enable = true;
      postgresql.enable = true;
      redis.enable = true;
      mongodb.enable = false; # builds from source
      android.enable = false; # ~10 GB
      ios.enable = false;
    };

    remote = {
      tailscale.enable = false;
      xrdp.enable = false;
      vnc.enable = false;
    };

    keyboards = {
      zsa.enable = false;
      appleFnKeys = false;
    };
  };

  # Set at install time — don't change it later.
  system.stateVersion = "26.05";
}
