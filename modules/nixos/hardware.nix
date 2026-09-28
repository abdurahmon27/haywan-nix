# GPU drivers, audio, bluetooth, firmware.
{ config, lib, pkgs, ... }:

let
  cfg = config.haywan.hardware;
in
{
  options.haywan.hardware = {
    gpu = lib.mkOption {
      type = lib.types.enum [ "nvidia" "amd" "intel" "none" ];
      default = "none";
      description = "Which GPU driver stack to set up.";
    };
    audio.enable = lib.mkEnableOption "PipeWire audio" // { default = true; };
    bluetooth.enable = lib.mkEnableOption "Bluetooth + Blueman" // { default = true; };
  };

  config = lib.mkMerge [
    {
      hardware.enableAllFirmware = true;
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };
    }

    (lib.mkIf (cfg.gpu == "nvidia") {
      services.xserver.videoDrivers = [ "nvidia" ];
      boot.kernelParams = [ "nvidia-drm.modeset=1" ];
      hardware.nvidia = {
        package = config.boot.kernelPackages.nvidiaPackages.production;
        modesetting.enable = true;
        powerManagement.enable = true;
        nvidiaSettings = true;
        # Proprietary kernel module — required for GTX 16xx and older.
        open = lib.mkDefault false;
      };
      environment.variables = {
        LIBVA_DRIVER_NAME = "nvidia";
        VDPAU_DRIVER = "nvidia";
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      };
    })

    (lib.mkIf (cfg.gpu == "amd") {
      services.xserver.videoDrivers = [ "amdgpu" ];
      hardware.amdgpu.initrd.enable = true;
    })

    (lib.mkIf (cfg.gpu == "intel") {
      services.xserver.videoDrivers = [ "modesetting" ];
      hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];
    })

    (lib.mkIf cfg.audio.enable {
      services.pulseaudio.enable = false;
      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        jack.enable = true;
      };
      environment.systemPackages = with pkgs; [ alsa-utils sof-firmware ];
    })

    (lib.mkIf cfg.bluetooth.enable {
      hardware.bluetooth.enable = true;
      services.blueman.enable = true;
    })
  ];
}
