# Talk to iPhones/iPads over USB (xtool sideloading, ideviceinfo, …).
{ config, lib, pkgs, ... }:

{
  options.haywan.dev.ios.enable = lib.mkEnableOption "iOS device tools (usbmuxd, libimobiledevice)";

  config = lib.mkIf config.haywan.dev.ios.enable {
    services.usbmuxd.enable = lib.mkDefault true;
    environment.systemPackages = with pkgs; [ libimobiledevice socat ];
  };
}
