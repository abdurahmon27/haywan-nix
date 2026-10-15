# OBS starting point: a "Stream" and a "Recording" profile plus a "Screen" scene.
# OBS rewrites its own config, so these are seeded once (never overwritten) rather
# than symlinked read-only. To start over: rm -r ~/.config/obs-studio, then rebuild.
{ config, lib, osConfig, ... }:

{
  config = lib.mkIf (osConfig.haywan.media.obs.enable or false) {
    home.activation.seedObs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p ${config.xdg.configHome}/obs-studio ${config.home.homeDirectory}/Videos/OBS
      run cp -r --update=none --no-preserve=mode ${../../dotfiles/obs}/. ${config.xdg.configHome}/obs-studio/
    '';
  };
}
