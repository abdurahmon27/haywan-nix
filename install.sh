#!/usr/bin/env bash
# Creates hosts/<hostname>/ for this machine by asking a few questions.
# It only writes files inside this repo; applying them is a separate, explicit step.
set -euo pipefail

cd "$(dirname "$0")"

bold=$'\e[1m' dim=$'\e[2m' green=$'\e[32m' yellow=$'\e[33m' reset=$'\e[0m'

ask() { # ask <prompt> <default>
  local answer
  read -rp "$1 ${dim}[$2]${reset} " answer
  echo "${answer:-$2}"
}

yes_no() { # yes_no <prompt> <y|n> -> prints true/false
  local answer
  read -rp "$1 ${dim}[$2]${reset} " answer
  answer="${answer:-$2}"
  [[ "$answer" =~ ^[Yy] ]] && echo true || echo false
}

if [ ! -e /etc/NIXOS ]; then
  echo "This installer is for NixOS. On other distros, import homeModules.default into your own Home Manager flake." >&2
  exit 1
fi

echo "${bold}haywan-nix${reset} — let's describe this machine. Press Enter to accept a default."
echo

# ── Detect sensible defaults ────────────────────────────────────────────────
gpu_default=none
if command -v lspci >/dev/null; then
  gpus=$(lspci | grep -Ei 'vga|3d|display' || true)
  if grep -qi nvidia <<<"$gpus"; then gpu_default=nvidia
  elif grep -qiE 'amd|ati' <<<"$gpus"; then gpu_default=amd
  elif grep -qi intel <<<"$gpus"; then gpu_default=intel
  fi
fi

loader_default=systemd-boot
[ -d /boot/grub ] && loader_default=grub

tz_default=$(timedatectl show -p Timezone --value 2>/dev/null || echo UTC)
state_version=$(nixos-version | cut -d. -f1-2)

# ── System ──────────────────────────────────────────────────────────────────
echo "${bold}System${reset}"
host=$(ask "Hostname:" "$(hostname)")
user=$(ask "Username:" "$USER")
full_name=$(ask "Full name:" "$(getent passwd "$user" | cut -d: -f5 | cut -d, -f1)")
tz=$(ask "Time zone:" "$tz_default")
loader=$(ask "Boot loader (grub / systemd-boot):" "$loader_default")
gpu=$(ask "GPU (nvidia / amd / intel / none):" "$gpu_default")
desktop=$(yes_no "Hyprland desktop?" y)
gaming=$(yes_no "Gaming (Steam, GameMode)?" n)
obs=$(yes_no "OBS Studio + virtual camera?" n)
docker=$(yes_no "Docker?" n)
postgres=$(yes_no "PostgreSQL?" n)
redis=$(yes_no "Redis?" n)
android=$(yes_no "Android SDK + emulator (~10 GB)?" n)
tailscale=$(yes_no "Tailscale?" n)
echo

# ── Home ────────────────────────────────────────────────────────────────────
echo "${bold}Your apps${reset}"
git_name=$(ask "Git name:" "$full_name")
git_email=$(ask "Git email:" "$user@$host")
browsers=$(yes_no "Browsers (Chrome, Firefox)?" y)
chat=$(yes_no "Chat (Telegram, Discord)?" y)
editors=$(yes_no "VS Code?" y)
cli=$(yes_no "CLI tools (btop, ripgrep, fd, jq…)?" y)
dev=$(yes_no "Dev tools (Node, Python, Go, Claude Code)?" n)
cloud=$(yes_no "Cloud (gcloud, MongoDB Compass)?" n)
media=$(yes_no "Media (VLC, mpv, ffmpeg)?" y)
fun=$(yes_no "Terminal toys (cava, cmatrix, nyancat)?" n)
echo

# ── Write hosts/<host> ──────────────────────────────────────────────────────
dir="hosts/$host"
if [ -e "$dir" ]; then
  [ "$(yes_no "$dir already exists. Overwrite?" n)" = true ] || exit 1
fi
mkdir -p "$dir"

if [ -r /etc/nixos/hardware-configuration.nix ]; then
  cp /etc/nixos/hardware-configuration.nix "$dir/"
else
  nixos-generate-config --show-hardware-config >"$dir/hardware-configuration.nix"
fi

cat >"$dir/default.nix" <<EOF
{ ... }:

{
  imports = [ ./hardware-configuration.nix ];

  haywan = {
    user = {
      name = "$user";
      description = "$full_name";
    };
    timeZone = "$tz";
    boot.loader = "$loader";
    hardware.gpu = "$gpu";

    desktop.enable = $desktop;
    gaming.enable = $gaming;
    media.obs.enable = $obs;

    dev = {
      docker.enable = $docker;
      postgresql.enable = $postgres;
      redis.enable = $redis;
      android.enable = $android;
    };

    remote.tailscale.enable = $tailscale;
  };

  system.stateVersion = "$state_version";
}
EOF

cat >"$dir/home.nix" <<EOF
{ pkgs, ... }:

{
  haywan = {
    shell.enable = true;

    git = {
      enable = true;
      name = "$git_name";
      email = "$git_email";
    };

    apps = {
      browsers.enable = $browsers;
      chat.enable = $chat;
      editors.enable = $editors;
      cli.enable = $cli;
      dev.enable = $dev;
      cloud.enable = $cloud;
      media.enable = $media;
      fun.enable = $fun;
    };

    desktop.phrases.enable = true;
  };

  home.packages = with pkgs; [ ];
}
EOF

# Flakes only see files tracked by git.
git add "$dir" 2>/dev/null || true

echo "${green}Wrote $dir/${reset}"
echo
echo "Next steps:"
echo "  1. Look it over:      \$EDITOR $dir/default.nix $dir/home.nix"
echo "  2. Test-build it:     nixos-rebuild build --flake .#$host"
echo "  3. Switch to it:      sudo nixos-rebuild switch --flake .#$host"
echo
echo "${yellow}Existing dotfiles Home Manager takes over are kept as *.hm-bak.${reset}"
echo "If flakes aren't enabled yet, use this for the first switch:"
echo "  sudo env NIX_CONFIG='experimental-features = nix-command flakes' nixos-rebuild switch --flake .#$host"
