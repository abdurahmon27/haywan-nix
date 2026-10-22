# GPU drivers, audio, bluetooth, firmware.
{ config, lib, pkgs, utils, ... }:

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
    fingerprint.enable = lib.mkEnableOption "the fingerprint reader for sudo and polkit prompts";
    faceUnlock = {
      enable = lib.mkEnableOption "Howdy face unlock (IR camera) for sudo, polkit and the lock screen";
      camera = lib.mkOption {
        type = lib.types.str;
        example = "/dev/v4l/by-path/pci-0000:00:14.0-usb-0:8:1.2-video-index0";
        description = "The IR camera. A /dev/v4l/by-path link: /dev/videoN numbers shift when v4l2loopback (OBS) loads.";
      };
    };
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

    (lib.mkIf cfg.fingerprint.enable {
      # fprintd turns on pam_fprintd for every PAM service (sudo, su, polkit, ...).
      services.fprintd.enable = true;
      # The login screen keeps asking for the password: a fingerprint can't unlock
      # the keyring, and ReGreet would sit waiting on the sensor before offering it.
      security.pam.services.greetd.fprintAuth = false;
      # Synaptics sensors often need a firmware update (fwupdmgr) before enrolling works.
      services.fwupd.enable = true;
    })

    (lib.mkIf cfg.faceUnlock.enable {
      # A face is enough on its own; a failed or timed-out scan falls through to finger/password.
      services.howdy = {
        enable = true;
        control = "sufficient";
        settings.video.device_path = cfg.faceUnlock.camera;
      };
      # Turns the IR LEDs on, so it works in the dark. One-time: `sudo linux-enable-ir-emitter configure`.
      services.linux-enable-ir-emitter = {
        enable = true;
        device = lib.removePrefix "dev-" (utils.escapeSystemdPath cfg.faceUnlock.camera);
      };
      # Same reason as the fingerprint: a face can't unlock the keyring at login.
      security.pam.services.greetd.howdy.enable = false;
    })

    # pam_fprintd comes first by default and holds the prompt until the finger scan times out.
    # Look for the face first instead: it takes a couple of seconds and needs no touch.
    (lib.mkIf (cfg.faceUnlock.enable && cfg.fingerprint.enable) {
      security.pam.services = lib.genAttrs [ "sudo" "su" "polkit-1" ] (name: {
        rules.auth.howdy.order = config.security.pam.services.${name}.rules.auth.fprintd.order - 1;
      });
    })
  ];
}
