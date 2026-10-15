# Claude Code usage limits: a Waybar module plus a prompt hook that holds
# non-urgent prompts when an account is nearly out.
#   haywan.claudeLimits.enable = true;
# Scripts live in ../../dotfiles/claude-limits.
{ config, lib, pkgs, ... }:

let
  cfg = config.haywan.claudeLimits;
  dotfiles = ../../dotfiles;
  home = config.home.homeDirectory;

  absolute = dir: if lib.hasPrefix "/" dir then dir else "${home}/${dir}";
  dirs = map (a: absolute a.configDir) cfg.accounts;

  configFile = pkgs.writeText "claude-limits.json" (builtins.toJSON {
    accounts = map (a: { inherit (a) name label; dir = absolute a.configDir; }) cfg.accounts;
    inherit (cfg) thresholds model;
  });

  script = name: file: runtimeInputs: pkgs.writeShellApplication {
    inherit name runtimeInputs;
    text = ''
      config=${configFile}
    '' + builtins.readFile (dotfiles + "/claude-limits/${file}");
  };

  fetch = script "claude-limits-fetch" "fetch.sh" (with pkgs; [ coreutils curl jq ]);
  # `claude` itself comes from your PATH, so the hook uses whatever version you run.
  guard = script "claude-limits-guard" "guard.sh" (with pkgs; [ coreutils gnugrep jq fetch ]);
  bar = script "claude-limits-waybar" "waybar.sh" (with pkgs; [ coreutils jq ]);

  # A stable path, so settings.json doesn't change on every rebuild.
  hookCommand = "${config.home.profileDirectory}/bin/claude-limits-guard";

  # Claude Code writes to its own settings.json, so it can't be a read-only Nix
  # file. Instead the hook entry is merged in on every switch, and taken back out
  # when the module is turned off. Other hooks and settings are left alone.
  syncHooks = enable: pkgs.writeShellScript "claude-limits-sync-hooks" ''
    for dir in ${lib.escapeShellArgs dirs}; do
      [ -d "$dir" ] || continue
      settings="$dir/settings.json"
      ${if enable then ''[ -f "$settings" ] || echo '{}' >"$settings"''
        else ''grep -qs claude-limits-guard "$settings" || continue''}
      ${pkgs.jq}/bin/jq --arg cmd ${lib.escapeShellArg hookCommand} --argjson on ${lib.boolToString enable} '
        def ours: (.command // "") | contains("claude-limits-guard");
        .hooks.UserPromptSubmit = [
          .hooks.UserPromptSubmit[]? | .hooks |= map(select(ours | not)) | select(.hooks != [])
        ]
        | if $on then .hooks.UserPromptSubmit += [{ hooks: [{ type: "command", command: $cmd, timeout: 45 }] }] else . end
        | if .hooks.UserPromptSubmit == [] then del(.hooks.UserPromptSubmit) else . end
        | if .hooks == {} then del(.hooks) else . end
      ' "$settings" >"$settings.tmp" || {
        echo "claude-limits: $settings isn't valid JSON, left it alone" >&2
        rm -f "$settings.tmp"
        continue
      }
      # Compare content, not formatting, so an unchanged file isn't rewritten.
      if ${pkgs.diffutils}/bin/cmp -s <(${pkgs.jq}/bin/jq -S . "$settings") <(${pkgs.jq}/bin/jq -S . "$settings.tmp"); then
        rm "$settings.tmp"
      else
        cat "$settings.tmp" >"$settings" && rm "$settings.tmp"
      fi
    done
  '';
in
{
  options.haywan.claudeLimits = {
    enable = lib.mkEnableOption "Claude Code usage limits in Waybar, and a hook that holds non-urgent prompts near the limit";

    accounts = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Shown in the tooltip, and names the cache file.";
          };
          configDir = lib.mkOption {
            type = lib.types.str;
            description = "The account's CLAUDE_CONFIG_DIR, absolute or relative to your home.";
          };
          label = lib.mkOption {
            type = lib.types.str;
            default = "󰚩";
            description = "Shown in the bar before the percentage.";
          };
        };
      });
      default = [{ name = "claude"; configDir = ".claude"; }];
      example = lib.literalExpression ''
        [
          { name = "personal"; configDir = ".claude"; label = "󰚩"; }
          { name = "work"; configDir = ".config/claude-work"; label = "W"; }
        ]
      '';
      description = ''
        Your Claude Code accounts, in bar order. Each one is checked with its own
        credentials, and its hook only ever looks at its own account.
      '';
    };

    thresholds = {
      warn = lib.mkOption {
        type = lib.types.int;
        default = 70;
        description = "From this %, each prompt gets a note suggesting a cheaper model. Below it, nothing.";
      };
      triage = lib.mkOption {
        type = lib.types.int;
        default = 90;
        description = "From this %, `model` reads each prompt and holds it unless it's urgent.";
      };
      block = lib.mkOption {
        type = lib.types.int;
        default = 98;
        description = "From this %, every prompt is held. Start one with `!urgent` to send it anyway.";
      };
    };

    model = lib.mkOption {
      type = lib.types.str;
      default = "haiku";
      description = "The model that decides whether a prompt is urgent. Runs on the same account.";
    };

    waybar = lib.mkOption {
      type = lib.types.bool;
      default = config.haywan.desktop.enable;
      defaultText = lib.literalExpression "config.haywan.desktop.enable";
      description = "Show the limits in the top bar.";
    };
  };

  config = lib.mkMerge [
    # Runs when off too, so turning the module off removes the hook again.
    {
      home.activation.claudeLimitsHooks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${syncHooks cfg.enable}
      '';
    }

    (lib.mkIf cfg.enable {
      home.packages = [ fetch guard ];

      systemd.user.services.claude-limits-fetch = {
        Unit.Description = "Fetch Claude Code usage limits";
        Service = {
          Type = "oneshot";
          ExecStart = lib.getExe fetch;
          ExecStartPost = "-${pkgs.procps}/bin/pkill -RTMIN+9 waybar";
        };
      };
      systemd.user.timers.claude-limits-fetch = {
        Unit.Description = "Fetch Claude Code usage limits every 2 minutes";
        Timer = { OnStartupSec = "15s"; OnUnitActiveSec = "2min"; };
        Install.WantedBy = [ "timers.target" ];
      };

      programs.waybar.settings.top = lib.mkIf cfg.waybar {
        modules-right = lib.mkBefore [ "custom/claude-limits" ];
        "custom/claude-limits" = {
          exec = lib.getExe bar;
          return-type = "json";
          interval = 30;
          signal = 9;
          on-click = "${pkgs.systemd}/bin/systemctl --user start claude-limits-fetch.service";
          tooltip = true;
        };
      };
    })
  ];
}
