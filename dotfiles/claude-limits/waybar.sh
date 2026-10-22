# Waybar module: every account's usage, from the cache claude-limits-fetch keeps.
# $config is prepended by modules/home/claude-limits.nix.
#
# The bar shows Claude's ✻ and one chip per account — label, a ring, and the fuller
# of the two windows as a percentage. The tooltip breaks that down per window: a
# progress line, the percentage, when it resets (countdown and clock time), and
# what the prompt hook is currently doing about it.

cache="${XDG_CACHE_HOME:-$HOME/.cache}/claude-limits"

accounts=$(jq -r '.accounts[] | [.name, .label] | @tsv' "$config" \
  | while IFS=$'\t' read -r name label; do
    jq -c --arg name "$name" --arg label "$label" '. + { name: $name, label: $label }' \
      "$cache/$name.json" 2>/dev/null \
      || jq -nc --arg name "$name" --arg label "$label" \
        '{ name: $name, label: $label, ok: false, error: "no data yet" }'
  done | jq -s .)

jq -c --argjson a "$accounts" '
  (now | floor) as $now
  | .thresholds as $t

  | def pad($n): if $n <= 0 then "" else " " * $n end;
    def rpad($n): . + pad($n - length);
    def lpad($n): pad($n - length) + .;
    def rep($s; $n): if $n <= 0 then "" else $s * $n end;
    # Everything below is Pango markup, so anything read off disk has to be escaped.
    def esc: tostring | gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;");

    # Four steps, one per thing the prompt hook starts doing at that level.
    def level: if . == null then "none"
      elif . >= $t.block then "block"
      elif . >= $t.triage then "triage"
      elif . >= $t.warn then "warn"
      else "ok" end;
    def colour: { ok: "#a9b665", warn: "#d8a657", triage: "#e78a4e",
                  block: "#ea6962", none: "#928374" }[level];
    def tint($s): "<span fgcolor=\"\(colour)\">\($s)</span>";
    def faint($s): "<span fgcolor=\"#928374\">\($s)</span>";
    def ghost($s): "<span fgcolor=\"#7c6f64\">\($s)</span>";

    # A filled run of ━, then the same glyph at low alpha for the track: one smooth
    # line tinted by its level (━ joins up seamlessly in a monospace font).
    def meter($cells):
      (if . == null then 0 else (. / 100 * $cells | round) end) as $f
      | (if $f > $cells then $cells elif $f < 0 then 0 else $f end) as $f
      | "<span fgcolor=\"\(colour)\">\(rep("━"; $f))"
        + "<span fgalpha=\"18%\">\(rep("━"; $cells - $f))</span></span>";
    # A ring that fills in eighths; an empty circle below one eighth.
    def ring:
      if . == null then ghost("󰝦")
      else (. / 12.5 | ceil) as $i
        | tint(if $i <= 0 then "󰝦" else ["󰪞","󰪟","󰪠","󰪡","󰪢","󰪣","󰪤","󰪥"][[$i, 8] | min - 1] end)
      end;
    def shown: if . == null then "—" else "\(floor)%" end;
    def claude: "<span fgcolor=\"#d97757\">✻</span>";

    def epoch: if . == null then null else (.[0:19] + "Z" | fromdateiso8601) end;
    def ago: if . == null then "—"
      elif . < 60 then "under a minute"
      elif . < 3600 then "\(. / 60 | floor)m"
      elif . < 86400 then "\(. / 3600 | floor)h \((. % 3600) / 60 | floor | tostring | lpad(2) | sub(" "; "0"))m"
      else "\(. / 86400 | floor)d \((. % 86400) / 3600 | floor)h" end;
    def until: epoch | if . == null then null else . - $now end;
    # Local clock time of a reset: "19:00" today, "tomorrow 04:00", else "Wed 04:00".
    def day: strflocaltime("%Y-%m-%d");
    def clock:
      if . == null then null
      elif day == ($now | day) then strflocaltime("%H:%M")
      elif day == ($now + 86400 | day) then strflocaltime("tomorrow %H:%M")
      else strflocaltime("%a %H:%M") end;

    def window($name; $w):
      "   " + faint($name | rpad(8)) + ($w.pct | meter(22))
      + "  " + ($w.pct | tint("<b>\(shown | lpad(4))</b>")) + "\n"
      + "   " + pad(8) + ghost(
          ($w.resets | epoch) as $e
          | if $e == null then "no reset time yet"
            # +30: resets come a moment before the minute (18:59:59.8); round to it.
            else "resets in " + ($e - $now | ago) + " · " + ($e + 30 | clock) end);

    def doing: { warn: "a cheaper model is suggested each prompt",
                 triage: "non-urgent prompts are held",
                 block: "every prompt is held · !urgent sends anyway" }[level];

    ($a | map(. + {
        peak: ([.five_hour.pct, .seven_day.pct] | map(select(. != null)) | max),
        stale: ($now - (.updated // 0) > 900)
      })) as $a
  # null, not 0, when nothing has reported yet: an empty bar is not a healthy one.
  | ($a | map(.peak) | map(select(. != null)) | max) as $top
  | {
      text: (claude + "   " + ($a | map(
          # Two spaces: an icon label (󰚩) draws wider than its cell and would touch the ring.
          faint(.label | esc) + "  " + (.peak | ring) + " " + (.peak | tint(shown))
          + (if .ok | not then " " + ghost("󰀦") elif .stale then " " + ghost("󰔟") else "" end)
        ) | join("   "))),

      tooltip: (claude + "  <b>Claude usage</b>\n" + ghost(rep("─"; 39)) + "\n"
        + ($a | map(
          faint(.label | esc) + "  <b>" + (.name | esc) + "</b>\n"
          + (if .ok | not then "   " + faint("󰀦 " + (.error | esc)) + "\n"
             elif .stale then "   " + faint("󰔟 these numbers are stale") + "\n"
             else "" end)
          + window("5-hour"; .five_hour) + "\n"
          + window("weekly"; .seven_day)
          + ((.peak | doing) as $d
             | if $d == null then "" else "\n   " + (.peak | tint("<i>\($d)</i>")) end)
        ) | join("\n\n"))
        + "\n" + ghost(rep("─"; 39)) + "\n" + ghost("updated "
          + (($a | map(.updated // 0) | max) as $u
             | if $u == 0 then "never"
               elif $now - $u < 60 then "just now"
               else ($now - $u | ago) + " ago" end)
          + " · click to refresh")),

      class: [$top | level]
        + (if $a | any(.stale or (.ok | not)) then ["stale"] else [] end),
      percentage: ($top // 0 | floor)
    }' "$config"
