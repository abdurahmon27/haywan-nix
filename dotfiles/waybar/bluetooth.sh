# Waybar Bluetooth: off, on, or the connected device's type with its battery underneath.
# Prefers an audio device when several are connected; the tooltip lists them all.

if [ "$(bluetoothctl show 2>/dev/null | awk '/Powered:/ { print $2; exit }')" != yes ]; then
  jq -nc '{ text: "󰂲", class: "off", tooltip: "Bluetooth is off" }'
  exit 0
fi

mapfile -t macs < <(bluetoothctl devices Connected 2>/dev/null | awk '/^Device/ { print $2 }')
if [ "${#macs[@]}" -eq 0 ]; then
  jq -nc '{ text: "󰂯", class: "on", tooltip: "Bluetooth is on, nothing connected" }'
  exit 0
fi

text=""
audio=false
tooltip=()
for mac in "${macs[@]}"; do
  info=$(bluetoothctl info "$mac")
  name=$(awk -F': ' '/^\s*Alias:/ { print $2; exit }' <<<"$info")
  kind=$(awk '/^\s*Icon:/ { print $2; exit }' <<<"$info")
  # "Battery Percentage: 0x50 (80)"
  battery=$(awk -F'[()]' '/Battery Percentage:/ { print $2; exit }' <<<"$info")

  case "$kind" in
    audio-headphones | audio-headset) icon="󰋋" ;;
    audio-card | audio-speakers) icon="󰓃" ;;
    input-mouse) icon="󰍽" ;;
    input-keyboard) icon="󰌌" ;;
    input-gaming) icon="󰊴" ;;
    phone) icon="󰏲" ;;
    computer) icon="󰌢" ;;
    *) icon="󰂱" ;;
  esac

  tooltip+=("$icon  $name${battery:+  ·  $battery%}")
  if [ -z "$text" ] || { ! $audio && [[ "$kind" == audio-* ]]; }; then
    text="$icon${battery:+$'\n'<small>$battery%</small>}"
    [[ "$kind" != audio-* ]] || audio=true
  fi
done

jq -nc --arg text "$text" --arg tooltip "$(printf '%s\n' "${tooltip[@]}")" \
  '{ text: $text, class: "connected", tooltip: ($tooltip | rtrimstr("\n")) }'
