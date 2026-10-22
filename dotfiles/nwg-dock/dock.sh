# Runs the dock only while some app is open: with no windows nwg-dock still draws
# an empty sliver at the bottom edge. Follows Hyprland's event socket, so it reacts
# the moment a window opens or the last one closes. Arguments go to nwg-dock-hyprland.
#
# Also guards the auto-hide: nwg-dock can miss the pointer leaving (after its window
# menu or a tooltip) and then stays up. While it's showing, a watch on the pointer
# hides it (SIGRTMIN+3) soon after the pointer is clearly elsewhere.

sock="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
dock=""
guard=""

# While the dock is up: hide it once the pointer has been away ~0.3 s. Directly above
# it (where its window menu pops up) allow 2.5 s, so picking a window isn't cut off.
watch_pointer() {
  local x y w h mx my away=0 limit
  # The open event can arrive before Hyprland lists the layer; give it up to ~1 s.
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    read -r x y w h < <(hyprctl layers -j |
      jq -r '[.. | objects | select(.namespace? == "nwg-dock")][0] | "\(.x) \(.y) \(.w) \(.h)"')
    if [[ "$h" =~ ^[0-9]+$ ]] && ((h > 0)); then break; fi
    sleep 0.1
  done
  [[ "$h" =~ ^[0-9]+$ ]] || return 0
  while sleep 0.15; do
    IFS=', ' read -r mx my < <(hyprctl cursorpos)
    if ((mx >= x - 6 && mx <= x + w + 6 && my >= y - 6)); then
      away=0 # on the dock, or between it and the screen edge
      continue
    fi
    limit=2
    if ((mx >= x - 120 && mx <= x + w + 120 && my >= y - 300)); then limit=16; fi
    if ((++away >= limit)); then
      kill -RTMIN+3 "$dock" 2>/dev/null || true
      return 0
    fi
  done
}

# Written with if, not `&&`: this runs under `set -e` (writeShellApplication).
stop_guard() {
  if [ -n "$guard" ]; then kill "$guard" 2>/dev/null || true; fi
  guard=""
}

update_dock() {
  if [ "$(hyprctl clients -j | jq 'length')" -gt 0 ]; then
    if [ -z "$dock" ] || ! kill -0 "$dock" 2>/dev/null; then
      nwg-dock-hyprland "$@" &
      dock=$!
    fi
  elif [ -n "$dock" ]; then
    kill "$dock" 2>/dev/null || true
    wait "$dock" 2>/dev/null || true
    dock=""
  fi
}

trap 'stop_guard; if [ -n "$dock" ]; then kill "$dock" 2>/dev/null || true; fi; exit 0' TERM INT HUP EXIT

update_dock "$@"
# Read in this shell (not a pipeline's subshell), so the trap sees $dock.
while read -r event; do
  case "$event" in
    openwindow\>\>* | closewindow\>\>*) update_dock "$@" ;;
    openlayer\>\>nwg-dock)
      stop_guard
      watch_pointer &
      guard=$!
      ;;
    closelayer\>\>nwg-dock) stop_guard ;;
  esac
done < <(socat -U - "UNIX-CONNECT:$sock")
