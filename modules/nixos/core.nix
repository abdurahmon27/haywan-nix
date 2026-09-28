# Always on: boot, nix, locale, networking, the main user, zsh.
{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.haywan;
in
{
  options.haywan = {
    user = {
      name = lib.mkOption {
        type = lib.types.str;
        example = "alice";
        description = "Login name of the main user.";
      };
      description = lib.mkOption {
        type = lib.types.str;
        default = cfg.user.name;
        description = "Full name / GECOS field.";
      };
      extraGroups = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Groups on top of the ones the enabled modules add.";
      };
    };

    timeZone = lib.mkOption {
      type = lib.types.str;
      default = "UTC";
      example = "Asia/Tashkent";
    };

    locale = lib.mkOption {
      type = lib.types.str;
      default = "en_US.UTF-8";
    };

    boot.loader = lib.mkOption {
      type = lib.types.enum [ "grub" "systemd-boot" ];
      default = "systemd-boot";
      description = "`grub` also detects other OSes (dual boot).";
    };
  };

  config = {
    # ── Boot ────────────────────────────────────────────────────────────────
    boot.loader = lib.mkMerge [
      { efi.canTouchEfiVariables = true; }
      (lib.mkIf (cfg.boot.loader == "grub") {
        grub = {
          enable = true;
          efiSupport = true;
          devices = [ "nodev" ];
          useOSProber = true;
        };
      })
      (lib.mkIf (cfg.boot.loader == "systemd-boot") {
        systemd-boot.enable = true;
      })
    ];
    boot.kernelModules = [ "fuse" ];

    # ── Nix ─────────────────────────────────────────────────────────────────
    nix = {
      settings = {
        experimental-features = [ "nix-command" "flakes" ];
        auto-optimise-store = true;
        trusted-users = [ "root" "@wheel" ];
      };
      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 14d";
      };
      # `nix shell nixpkgs#foo` and `nix-shell -p foo` use the same nixpkgs as the system.
      registry.nixpkgs.flake = inputs.nixpkgs;
      nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    };

    nixpkgs.config.allowUnfree = true;

    # Newer Telegram from nixos-unstable; everything else stays on the stable channel.
    nixpkgs.overlays = [
      (final: prev: {
        inherit (import inputs.nixpkgs-unstable {
          inherit (prev.stdenv.hostPlatform) system;
          config.allowUnfree = true;
        }) telegram-desktop;
      })
    ];

    # ── Locale & network ────────────────────────────────────────────────────
    time.timeZone = cfg.timeZone;
    i18n.defaultLocale = cfg.locale;

    networking = {
      networkmanager.enable = true;
      nameservers = [ "1.1.1.1" "8.8.8.8" ];
    };

    # ── User ────────────────────────────────────────────────────────────────
    users.users.${cfg.user.name} = {
      isNormalUser = true;
      inherit (cfg.user) description;
      extraGroups = [ "wheel" "networkmanager" "audio" "video" "input" "fuse" ] ++ cfg.user.extraGroups;
      shell = pkgs.zsh;
    };

    programs.zsh = {
      enable = true;
      enableCompletion = true;
      syntaxHighlighting.enable = true;
      autosuggestions.enable = true;
    };
    # Completions for packages installed by Home Manager.
    environment.pathsToLink = [ "/share/zsh" ];

    # ── Run unpatched binaries (AppImages, npm/pip prebuilt binaries, Claude Code…) ──
    programs.fuse.userAllowOther = true;
    programs.nix-ld = {
      enable = true;
      libraries = with pkgs; [
        stdenv.cc.cc.lib
        zlib
        fuse3
        icu
        nss
        openssl
        curl
        expat
        fontconfig
        freetype
        libGL
        libgcc
        glibc
        xorg.libX11
        xorg.libXcursor
        xorg.libXrandr
        xorg.libXi
        libglvnd
      ];
    };

    environment.systemPackages = with pkgs; [
      git
      curl
      wget
      appimage-run
    ];

    security.polkit.enable = true;
    services.dbus.enable = true;
  };
}
