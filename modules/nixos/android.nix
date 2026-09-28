# React Native / Android: SDK + NDK + emulator, adb, KVM, JDK.
{ config, lib, pkgs, ... }:

let
  cfg = config.haywan.dev.android;

  androidSdk = (pkgs.androidenv.composeAndroidPackages {
    platformVersions = [ "36" "35" "34" ];
    buildToolsVersions = [ "36.0.0" "35.0.0" "34.0.0" ];
    includeEmulator = true;
    emulatorVersion = "36.2.4";
    includeSources = false;
    includeSystemImages = true;
    systemImageTypes = [ "google_apis" ];
    abiVersions = [ "x86_64" ];
    includeNDK = true;
    ndkVersions = [ "27.1.12297006" ];
    cmakeVersions = [ "3.22.1" ];
    includeExtras = [ "extras;google;gcm" ];
    extraLicenses = [
      "android-sdk-license"
      "android-googletv-license"
      "android-sdk-preview-license"
      "google-gdk-license"
      "intel-android-extra-license"
      "intel-android-sysimage-license"
      "mips-android-sysimage-license"
    ];
  }).androidsdk;

  sdkRoot = "${androidSdk}/libexec/android-sdk";
in
{
  options.haywan.dev.android.enable = lib.mkEnableOption "the Android SDK, emulator and adb (~10 GB)";

  config = lib.mkIf cfg.enable {
    nixpkgs.config.android_sdk.accept_license = true;

    programs.adb.enable = true;
    haywan.user.extraGroups = [ "adbusers" "kvm" ];

    environment.systemPackages = [ androidSdk pkgs.openjdk ];

    environment.variables = {
      ANDROID_HOME = sdkRoot;
      ANDROID_SDK_ROOT = sdkRoot;
      JAVA_HOME = "${pkgs.openjdk}";
    };

    environment.sessionVariables.PATH = [
      "${sdkRoot}/platform-tools"
      "${sdkRoot}/emulator"
      "${sdkRoot}/tools"
      "${sdkRoot}/tools/bin"
    ];
  };
}
