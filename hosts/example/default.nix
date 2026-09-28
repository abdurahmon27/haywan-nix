# A starting point for your own machine.
#   1. Copy this folder:  cp -r hosts/example hosts/<your-hostname>
#   2. Replace hardware-configuration.nix with yours:
#        cp /etc/nixos/hardware-configuration.nix hosts/<your-hostname>/
#   3. Flip the switches below, then:
#        sudo nixos-rebuild switch --flake .#<your-hostname>
{ ... }:

{
  imports = [ ./hardware-configuration.nix ];

  haywan = {
    user = {
      name = "alice";
      description = "Alice";
    };
    timeZone = "Europe/London";
    boot.loader = "systemd-boot"; # "grub" if you dual-boot

    hardware = {
      gpu = "intel"; # "nvidia" | "amd" | "intel" | "none"
      audio.enable = true;
      bluetooth.enable = true;
    };

    desktop.enable = true; # Hyprland

    gaming.enable = false; # Steam, GameMode, MangoHud
    media.obs.enable = false; # OBS + virtual camera

    dev = {
      docker.enable = false;
      postgresql.enable = false;
      redis.enable = false;
      mongodb.enable = false; # builds from source, takes a long time
      android.enable = false; # Android SDK + emulator, ~10 GB
      ios.enable = false; # usbmuxd + libimobiledevice
    };

    remote = {
      tailscale.enable = false;
      xrdp.enable = false;
      vnc.enable = false; # needs tailscale
    };

    keyboards = {
      zsa.enable = false; # ErgoDox EZ / Moonlander / Voyager
      appleFnKeys = false;
    };
  };

  # Set once at install time — don't change it later.
  system.stateVersion = "25.05";
}
