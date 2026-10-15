# Refreshes the usage cache for one account (by name) or, with no argument, all of them.
# $config is prepended by modules/home/claude-limits.nix.
#
# Each account's token is read from its own config dir and only sent with that
# account's own request. The cache keeps percentages and reset times, nothing else.

cache="${XDG_CACHE_HOME:-$HOME/.cache}/claude-limits"
mkdir -p "$cache"
chmod 700 "$cache"

fetch_one() {
  local name="$1" dir="$2"
  local out="$cache/$name.json" creds="$dir/.credentials.json"
  local now token expires body="" err=""
  now=$(date +%s)

  if [ ! -r "$creds" ]; then
    err="not logged in"
  else
    token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds")
    expires=$(jq -r '(.claudeAiOauth.expiresAt // 0) / 1000 | floor' "$creds")
    if [ -z "$token" ]; then
      err="not logged in"
    elif [ "$expires" -le "$now" ]; then
      # Claude Code refreshes it on its next start; we never touch the refresh token.
      err="token expired, open a session to refresh it"
    # Headers go through stdin so the token never shows up in `ps`.
    elif ! body=$(printf 'Authorization: Bearer %s\nanthropic-beta: oauth-2025-04-20\n' "$token" \
      | curl -fsS -m 10 -H @- https://api.anthropic.com/api/oauth/usage); then
      err="usage request failed"
    fi
  fi

  if [ -z "$err" ]; then
    jq --argjson now "$now" '{
      ok: true, checked: $now,
      five_hour: { pct: .five_hour.utilization, resets: .five_hour.resets_at },
      seven_day: { pct: .seven_day.utilization, resets: .seven_day.resets_at }
    }' <<<"$body" >"$out.tmp"
  elif [ -f "$out" ]; then
    # Keep the last numbers so the bar still shows something, flagged as stale.
    jq --arg err "$err" --argjson now "$now" '.ok = false | .error = $err | .checked = $now' "$out" >"$out.tmp"
  else
    jq -n --arg err "$err" --argjson now "$now" '{ ok: false, error: $err, checked: $now }' >"$out.tmp"
  fi
  mv "$out.tmp" "$out"
}

want="${1:-}"
while IFS=$'\t' read -r name dir; do
  if [ -z "$want" ] || [ "$want" = "$name" ]; then
    fetch_one "$name" "$dir" || echo "claude-limits-fetch: $name failed" >&2
  fi
done < <(jq -r '.accounts[] | [.name, .dir] | @tsv' "$config")
