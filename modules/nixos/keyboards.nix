{ config, lib, ... }:

{
  options.haywan.keyboards = {
    zsa.enable = lib.mkEnableOption "udev rules for ZSA keyboards (ErgoDox EZ, Moonlander, Voyager) — Oryx & Keymapp";
    appleFnKeys = lib.mkEnableOption "F1–F12 as function keys by default on Apple / Keychron keyboards";
  };

  config = lib.mkMerge [
    (lib.mkIf config.haywan.keyboards.appleFnKeys {
      boot.kernelParams = [ "hid_apple.fnmode=2" ];
    })

    (lib.mkIf config.haywan.keyboards.zsa.enable {
      services.udev.extraRules = ''
        # Rules for Oryx web flashing and live training
        KERNEL=="hidraw*", ATTRS{idVendor}=="16c0", MODE="0664", GROUP="plugdev"
        KERNEL=="hidraw*", ATTRS{idVendor}=="3297", MODE="0664", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="3297", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="3297", ATTR{idProduct}=="1969", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="feed", ATTR{idProduct}=="1307", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="feed", ATTR{idProduct}=="6060", GROUP="plugdev"
        ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789B]?", ENV{ID_MM_DEVICE_IGNORE}="1"
        ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789A]?", ENV{MTP_NO_PROBE}="1"
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789ABCD]?", MODE="0666"
        KERNEL=="ttyACM*", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789B]?", MODE="0666"
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", MODE="0666", SYMLINK+="stm32_dfu"
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="3297", MODE="0666", SYMLINK+="ignition_dfu"
      '';
    })
  ];
}
