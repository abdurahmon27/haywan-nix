# One of the player's buttons: prev, toggle or next. Follows the player and prints
# an empty line (so Waybar hides the button) while nothing is playing or paused.
button="$1"

playerctl --follow status 2>/dev/null | while read -r status; do
  if [ "$status" != Playing ] && [ "$status" != Paused ]; then
    echo
    continue
  fi
  case "$button" in
    prev) echo "󰒮" ;;
    next) echo "󰒭" ;;
    toggle) if [ "$status" = Playing ]; then echo "󰏤"; else echo "󰐊"; fi ;;
  esac
done
