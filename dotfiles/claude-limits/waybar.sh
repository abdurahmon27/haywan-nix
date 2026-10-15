# Waybar module: every account's fuller usage window, from the cache claude-limits-fetch keeps.
# $config is prepended by modules/home/claude-limits.nix.

cache="${XDG_CACHE_HOME:-$HOME/.cache}/claude-limits"

accounts=$(jq -r '.accounts[] | [.name, .label] | @tsv' "$config" \
  | while IFS=$'\t' read -r name label; do
    jq -c --arg name "$name" --arg label "$label" '. + { name: $name, label: $label }' \
      "$cache/$name.json" 2>/dev/null \
      || jq -nc --arg name "$name" --arg label "$label" \
        '{ name: $name, label: $label, ok: false, error: "no data yet" }'
  done | jq -s .)

jq -c --argjson a "$accounts" '
  def at: if . == null then "?"
    else .[0:19] + "Z" | fromdateiso8601 | localtime | strftime("%a %H:%M") end;
  def pct: if . == null then "?" else "\(floor)%" end;
  def line($w; $v): "  \($w): \($v.pct | pct) · resets \($v.resets | at)";

  .thresholds as $t
  | ($a | map(. + { peak: ([.five_hour.pct, .seven_day.pct] | map(select(. != null)) | max) })) as $a
  | ($a | map(.peak // 0) | max // 0) as $top
  | {
      text: ($a | map("\(.label) \(.peak | pct)\(if .ok then "" else "!" end)") | join("  ")),
      tooltip: ($a | map(
          "\(.name)\(if .ok then "" else " (\(.error))" end)\n"
          + line("5h"; .five_hour) + "\n" + line("week"; .seven_day)
        ) | join("\n\n")),
      class: (if $top >= $t.triage then "critical" elif $top >= $t.warn then "warn" else "normal" end),
      percentage: ($top | floor)
    }' "$config"
