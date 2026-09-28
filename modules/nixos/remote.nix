# Remote access. VNC is only reachable over Tailscale, never on Wi-Fi/LAN.
{ config, lib, pkgs, ... }:

let
  cfg = config.haywan.remote;
in
{
  options.haywan.remote = {
    tailscale.enable = lib.mkEnableOption "Tailscale";
    xrdp.enable = lib.mkEnableOption "an RDP server (port 3389, opened in the firewall)";
    vnc.enable = lib.mkEnableOption "wayvnc for the live Hyprland session (port 5900, Tailscale only)";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.tailscale.enable {
      services.tailscale.enable = true;
    })

    (lib.mkIf cfg.xrdp.enable {
      services.xrdp = {
        enable = true;
        defaultWindowManager = "Hyprland";
        openFirewall = true;
      };
    })

    (lib.mkIf cfg.vnc.enable {
      environment.systemPackages = [ pkgs.wayvnc ];
      networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 5900 ];
    })
  ];
}
