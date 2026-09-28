# haywan-nix

My NixOS setup — Hyprland, Gruvbox, zsh — as a flake with Home Manager, split into small switches so you can take only what you want.

- **One folder per machine.** Everything in `hosts/<name>/` becomes `nixosConfigurations.<name>` automatically.
- **Two files to edit.** `default.nix` for the system (drivers, services), `home.nix` for your apps and dotfiles.
- **Switches, not forks.** `haywan.gaming.enable = true;` — no need to touch the modules.
- **Plain dotfiles.** Hyprland, Kitty, Waybar and Rofi configs live in `dotfiles/` as normal config files.

## What you get

| | |
|---|---|
| Desktop | Hyprland, Waybar (top + vertical right bar), Rofi launcher, Kitty, Dunst, swww wallpaper slideshow |
| Login | ReGreet — a graphical Gruvbox login screen (or text-only tuigreet) |
| Theme | Gruvbox Material, Bibata cursor, Papirus icons, JetBrains Mono Nerd Font |
| Shell | zsh, Oh My Zsh (`git`, `z`, `sudo`), Powerlevel10k, syntax highlighting, autosuggestions |
| Hardware | NVIDIA / AMD / Intel, PipeWire, Bluetooth, ZSA keyboard rules |
| Dev | Docker, PostgreSQL, Redis, MongoDB, Android SDK + emulator, iOS device tools, nix-ld for prebuilt binaries |
| Extras | Steam, OBS with a virtual camera, Tailscale, RDP, VNC over Tailscale |

## Install

On a fresh (or existing) NixOS install:

```sh
nix-shell -p git --run "git clone https://github.com/abdurahmon27/haywan-nix ~/haywan-nix"
cd ~/haywan-nix
./install.sh
```

`install.sh` asks a few questions (hostname, GPU, which apps) and writes `hosts/<hostname>/`. It doesn't change your system. Then:

```sh
nixos-rebuild build --flake .#<hostname>          # test build, changes nothing
sudo nixos-rebuild switch --flake .#<hostname>    # apply
```

If flakes aren't enabled yet, run the first switch as:

```sh
sudo env NIX_CONFIG='experimental-features = nix-command flakes' nixos-rebuild switch --flake .#<hostname>
```

After that, flakes are on for good.

> Home Manager will take over files like `~/.zshrc` and `~/.config/hypr/hyprland.conf`. Your old ones are kept next to them as `*.hm-bak`.

Prefer doing it by hand? `cp -r hosts/example hosts/<hostname>`, copy in `/etc/nixos/hardware-configuration.nix`, and edit the two files.

## Pick what you want

### System — `hosts/<name>/default.nix`

```nix
haywan = {
  user = { name = "alice"; description = "Alice"; };
  timeZone = "Europe/London";
  boot.loader = "systemd-boot";     # or "grub" for dual boot

  hardware.gpu = "amd";             # nvidia | amd | intel | none
  desktop.enable = true;            # Hyprland
  desktop.greeter = "regreet";      # graphical login; "tuigreet" for text-only
  # desktop.greeterBackground = ./login.jpg;   # image inside your flake

  gaming.enable = true;             # Steam, GameMode, MangoHud
  media.obs.enable = true;          # OBS + virtual camera

  dev.docker.enable = true;
  dev.postgresql.enable = true;
  dev.redis.enable = true;
  dev.mongodb.enable = false;       # builds from source, slow
  dev.android.enable = false;       # SDK + NDK + emulator, ~10 GB
  dev.ios.enable = false;           # usbmuxd + libimobiledevice

  remote.tailscale.enable = true;
  remote.xrdp.enable = false;
  remote.vnc.enable = false;        # wayvnc, reachable over Tailscale only

  keyboards.zsa.enable = false;     # ErgoDox EZ / Moonlander / Voyager
  keyboards.appleFnKeys = false;
};
```

### Apps & dotfiles — `hosts/<name>/home.nix`

```nix
haywan = {
  shell.enable = true;
  git = { enable = true; name = "Alice"; email = "alice@example.com"; };

  apps = {
    browsers.enable = true;   # Chrome, Firefox
    chat.enable = true;       # Telegram, Discord
    editors.enable = true;    # VS Code
    cli.enable = true;        # btop, ripgrep, fd, jq, tree, fastfetch
    dev.enable = true;        # Node 22 + yarn + pnpm, Python, Go, watchman, Claude Code
    cloud.enable = false;     # Google Cloud SDK, MongoDB Compass
    media.enable = true;      # VLC, mpv, ffmpeg
    fun.enable = false;       # cava, cmatrix, asciiquarium, nyancat
  };

  desktop = {
    monitors = [ "eDP-1, 1920x1080@144, 0x0, 1" ];   # see `hyprctl monitors`
    browser = "firefox";
    wallpapers.dir = "/home/alice/Pictures/wallpapers";
  };
};

home.packages = with pkgs; [ obsidian spotify ];   # anything else
```

Every option lives in `modules/` with a description next to it.

### A phrase in your bar

The top bar can show a line of text that changes every hour.

I built it to keep a dhikr in front of me through the day — my own list stays out of this repo. Use it for whatever helps you: reminders, words you're learning, quotes.

```nix
haywan.desktop.phrases = {
  enable = true;
  items = [ "Stay curious" "Drink some water" "Ship it" ];
};
```

Or read them from a file on disk (one per line), or pull them out of any text file with a regex:

```nix
haywan.desktop.phrases = {
  enable = true;
  file = "/home/alice/notes/phrases.txt";
  # pattern = ''(?<=Say ")[^"]*'';
};
```

## Keybinds

| Keys | Action |
|---|---|
| `Super + Q` | Terminal (Kitty) |
| `Super + Space` / `Super + S` | App launcher |
| `Super + B` | Browser |
| `Super + I` | File manager (ranger) |
| `Super + C` | Close window |
| `Super + V` | Toggle floating |
| `Super + M` | Maximize |
| `Super + 1…0` | Switch workspace |
| `Super + Shift + 1…0` | Move window to workspace |
| `Super + Shift + S` | Screenshot a region to the clipboard |
| `Super + Shift + Q` | Exit Hyprland |

Edit them in [`dotfiles/hypr/binds.conf`](dotfiles/hypr/binds.conf).

## Layout

```
flake.nix
lib/                 host discovery
hosts/
  example/           start here
  haywan/            my laptop
modules/
  nixos/             system: core, hardware, desktop, gaming, dev, android, remote…
  home/              user: shell, git, apps, desktop (Hyprland/Waybar/Rofi/Kitty)
dotfiles/            plain config files the home modules link into ~/.config
install.sh
```

## Everyday use

```sh
sudo nixos-rebuild switch --flake .#<hostname>   # after editing anything
nix flake update                                 # update nixpkgs & Home Manager
sudo nixos-rebuild switch --rollback             # undo the last switch
```

Garbage collection runs weekly and keeps 14 days of generations.

## Use it from your own flake

```nix
{
  inputs.haywan-nix.url = "github:abdurahmon27/haywan-nix";

  outputs = { nixpkgs, haywan-nix, ... }: {
    nixosConfigurations.my-pc = nixpkgs.lib.nixosSystem {
      specialArgs.inputs = haywan-nix.inputs;
      modules = [
        haywan-nix.inputs.home-manager.nixosModules.home-manager
        haywan-nix.nixosModules.default
        ./configuration.nix
        {
          home-manager.sharedModules = [ haywan-nix.homeModules.default ];
          home-manager.users.alice = ./home.nix;
        }
      ];
    };
  };
}
```

## Credits

- Rofi launcher layout adapted from [adi1090x/rofi](https://github.com/adi1090x/rofi) (GPL-3.0).
- Colors from [Gruvbox Material](https://github.com/sainnhe/gruvbox-material).

## License

[MIT](LICENSE)
