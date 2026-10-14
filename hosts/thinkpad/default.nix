# haywan's ThinkPad — Intel i5-10210U, Intel UHD graphics, Hyprland.
# Lean on purpose: no Android SDK, no Steam, no OBS, no MongoDB — disk is tight.
{ config, ... }:

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
      tailscale.enable = true; # reach this box from anywhere, no port forwarding
      xrdp.enable = false;
      vnc.enable = false;
    };

    keyboards = {
      zsa.enable = false;
      appleFnKeys = false;
    };
  };

  # Runs closed on a cooling pad — don't suspend when the lid shuts.
  # (Renamed in 26.05: services.logind.lidSwitch -> settings.Login.HandleLidSwitch)
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };

  # nixpkgs leaves systemd-logind without a restart trigger on purpose (see the
  # commented-out line in nixos/modules/system/boot/systemd/logind.nix), so a plain
  # `switch` rewrites logind.conf while the running daemon keeps its old settings.
  # systemd can *reload* logind, which — unlike a restart — is safe for live sessions.
  systemd.services.systemd-logind.reloadTriggers = [
    config.environment.etc."systemd/logind.conf".source
  ];

  # A shell to reach this box from elsewhere. Bound to Tailscale only, never
  # exposed on whatever Wi-Fi the laptop happens to be sitting on.
  services.openssh = {
    enable = true;
    openFirewall = false;
  };
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 22 ];

  # Set at install time — don't change it later.
  system.stateVersion = "26.05";
}
