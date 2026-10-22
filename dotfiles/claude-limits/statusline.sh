# Claude Code status line: model, plus this account's 5-hour and weekly usage.
# $config is prepended by modules/home/claude-limits.nix.
#
# Claude Code runs this after every message, so it only reads the cache that
# claude-limits-fetch keeps; it never calls the usage endpoint itself.

input=$(cat)
dir=$(realpath -m "${CLAUDE_CONFIG_DIR:-$HOME/.claude}")
name=$(jq -r --arg d "$dir" 'first(.accounts[] | select(.dir == $d) | .name) // empty' "$config")
model=$(jq -r '.model.display_name // empty' <<<"$input")

cache="${XDG_CACHE_HOME:-$HOME/.cache}/claude-limits/$name.json"
if [ -z "$name" ] || [ ! -r "$cache" ]; then
  printf '%s\n' "${model:-Claude}"
  exit 0
fi

jq -rj --arg model "$model" --slurpfile c "$config" '
  $c[0].thresholds as $t
  | (now | floor) as $now
  | def color($p): if $p >= $t.block then "1;31" elif $p >= $t.triage then "31"
      elif $p >= $t.warn then "33" else "32" end;
    def at($fmt): if . == null then "?"
      else .[0:19] + "Z" | fromdateiso8601 | localtime | strftime($fmt) end;
    def part($w; $v; $fmt):
      if $v.pct == null then empty
      else "\u001b[\(color($v.pct))m\($w) \($v.pct | floor)%\u001b[0m \u001b[2m↻ \($v.resets | at($fmt))\u001b[0m" end;
  [ (if $model == "" then empty else $model end),
    part("5h"; .five_hour; "%H:%M"),
    part("week"; .seven_day; "%a %H:%M"),
    (if .ok then empty else "\u001b[2m(\(.error))\u001b[0m" end),
    (if $now - (.updated // 0) > 900 and .ok then "\u001b[2m(stale)\u001b[0m" else empty end)
  ] | join(" · ")' "$cache"
echo
