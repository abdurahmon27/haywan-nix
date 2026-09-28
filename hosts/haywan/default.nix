# haywan's laptop — Intel CPU + NVIDIA GTX 1650, Hyprland.
{ lib, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  haywan = {
    user = {
      name = "haywan";
      description = "abdurahmon";
    };
    timeZone = "Asia/Tashkent";
    boot.loader = "grub";

    hardware.gpu = "nvidia";
    desktop = {
      enable = true;
      keyboard.options = "altwin:super_win";
    };

    gaming.enable = true;
    media.obs.enable = true;

    dev = {
      docker.enable = true;
      postgresql.enable = true;
      redis.enable = true;
      android.enable = true;
      ios.enable = true;
    };

    remote = {
      tailscale.enable = true;
      xrdp.enable = true;
      vnc.enable = true;
    };

    keyboards = {
      zsa.enable = true;
      appleFnKeys = true;
    };
  };

  # ── Machine-specific bits ────────────────────────────────────────────────
  networking.hostName = "nixos";

  # xtool runs usbmuxd inside Docker, so the host daemon stays off.
  services.usbmuxd.enable = false;

  # Laptop lives closed on the desk, plugged into a monitor.
  services.logind = {
    lidSwitch = "ignore";
    lidSwitchExternalPower = "ignore";
  };

  # Expo/Metro (8081) only for the iPhone Personal Hotspot subnet, not regular Wi-Fi.
  networking.firewall.extraCommands = ''
    iptables -I nixos-fw -p tcp -s 172.20.10.0/28 --dport 8081 -j ACCEPT
  '';

  users.groups.abdurahmon = { };

  system.stateVersion = "25.05";
}
