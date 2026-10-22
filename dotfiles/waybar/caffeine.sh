# Caffeine: hold a logind idle inhibitor so hypridle never dims, locks or blanks the screen.
# Lid close and suspend still lock as usual.
#   caffeine          toggle
#   caffeine on|off   set it
#   caffeine status   JSON for the Waybar module

unit=caffeine

active() { systemctl --user is-active --quiet "$unit"; }

on() {
  active || systemd-run --user --quiet --collect --unit="$unit" \
    systemd-inhibit --what=idle --who=caffeine --why="Caffeine mode is on" sleep infinity
}

off() { systemctl --user stop "$unit" 2>/dev/null || true; }

case "${1:-toggle}" in
  on) on ;;
  off) off ;;
  toggle) if active; then off; else on; fi ;;
  status)
    if active; then
      jq -nc '{ text: "󰅶", class: "on", tooltip: "Caffeine on: the screen will not lock or turn off\nClick to turn off" }'
    else
      jq -nc '{ text: "󰛊", class: "off", tooltip: "Caffeine off: locks when idle\nClick to keep the screen awake" }'
    fi
    exit 0
    ;;
  *) echo "usage: caffeine [on|off|toggle|status]" >&2; exit 2 ;;
esac

# Refresh the bar icon right away.
pkill -RTMIN+10 waybar || true
