# Refreshes the usage cache for one account (by name) or, with no argument, all of them.
# $config is prepended by modules/home/claude-limits.nix.
#
# Each account's token is read from its own config dir and only sent with that
# account's own request. The cache keeps percentages and reset times, nothing else.

cache="${XDG_CACHE_HOME:-$HOME/.cache}/claude-limits"
mkdir -p "$cache"
chmod 700 "$cache"

# The endpoint rate-limits (HTTP 429). After one, nothing is sent for this
# account until Retry-After has passed (10 minutes when it doesn't say).
backoff=600

fetch_one() {
  local name="$1" dir="$2"
  local out="$cache/$name.json" creds="$dir/.credentials.json"
  local now token expires next code retry body headers err=""
  now=$(date +%s)

  next=$(jq -r '.next // 0' "$out" 2>/dev/null || echo 0)
  [ "$now" -ge "$next" ] || return 0

  body=$(mktemp)
  headers=$(mktemp)
  next=0

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
    else
      # Headers go through stdin so the token never shows up in `ps`.
      code=$(printf 'Authorization: Bearer %s\nanthropic-beta: oauth-2025-04-20\n' "$token" \
        | curl -sS -m 10 -H @- -D "$headers" -o "$body" -w '%{http_code}' \
          https://api.anthropic.com/api/oauth/usage) || code=000
      case "$code" in
        200) ;;
        429)
          retry=$(awk -F': *' 'tolower($1) == "retry-after" { print $2 + 0; exit }' "$headers")
          [ "${retry:-0}" -gt 0 ] || retry=$backoff
          next=$((now + retry))
          err="rate limited, next try at $(date -d "@$next" +%H:%M)"
          ;;
        401) err="token expired, open a session to refresh it" ;;
        *) err="usage request failed (HTTP $code)" ;;
      esac
    fi
  fi

  if [ -z "$err" ]; then
    jq --argjson now "$now" '{
      ok: true, checked: $now, updated: $now, next: 0,
      five_hour: { pct: .five_hour.utilization, resets: .five_hour.resets_at },
      seven_day: { pct: .seven_day.utilization, resets: .seven_day.resets_at }
    }' "$body" >"$out.tmp"
  else
    # Keep the last numbers, but a window whose reset has passed is back at 0.
    jq --arg err "$err" --argjson now "$now" --argjson next "$next" '
      def reset: if .resets != null and (.resets[0:19] + "Z" | fromdateiso8601) <= $now
        then .pct = 0 | .resets = null else . end;
      .ok = false | .error = $err | .checked = $now | .next = $next
      | if .five_hour then .five_hour |= reset else . end
      | if .seven_day then .seven_day |= reset else . end
    ' "$out" 2>/dev/null >"$out.tmp" \
      || jq -n --arg err "$err" --argjson now "$now" --argjson next "$next" \
        '{ ok: false, error: $err, checked: $now, next: $next }' >"$out.tmp"
  fi
  mv "$out.tmp" "$out"
  rm -f "$body" "$headers"
}

want="${1:-}"
while IFS=$'\t' read -r name dir; do
  if [ -z "$want" ] || [ "$want" = "$name" ]; then
    fetch_one "$name" "$dir" || echo "claude-limits-fetch: $name failed" >&2
  fi
done < <(jq -r '.accounts[] | [.name, .dir] | @tsv' "$config")
