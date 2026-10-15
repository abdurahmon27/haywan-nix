# Claude Code UserPromptSubmit hook. $config is prepended by modules/home/claude-limits.nix.
#
#   below warn    silent
#   warn..triage  a note to you: switch to a cheaper model
#   triage..block a small model decides if the prompt is urgent; if not, it's held
#   above block   everything is held
#
# Starting a prompt with !urgent always sends it.
#
# Everything stays inside the account the session runs as: the account is picked
# from CLAUDE_CONFIG_DIR, and the triage call inherits it and saves no transcript.

# The triage call below is itself a Claude Code run; don't gate it.
[ -z "${CLAUDE_LIMITS_INNER:-}" ] || exit 0

input=$(cat)
dir=$(realpath -m "${CLAUDE_CONFIG_DIR:-$HOME/.claude}")
name=$(jq -r --arg d "$dir" 'first(.accounts[] | select(.dir == $d) | .name) // empty' "$config")
[ -n "$name" ] || exit 0

cache="${XDG_CACHE_HOME:-$HOME/.cache}/claude-limits/$name.json"
now=$(date +%s)
checked=$(jq -r '.checked // 0' "$cache" 2>/dev/null || echo 0)
if [ $((now - checked)) -gt 300 ]; then
  claude-limits-fetch "$name" || true
fi
[ -r "$cache" ] || exit 0

# Whichever window is fuller decides.
read -r pct window resets < <(jq -r '
  [{ w: "5-hour", v: .five_hour }, { w: "weekly", v: .seven_day }]
  | map(select(.v.pct != null)) | max_by(.v.pct) // empty
  | "\(.v.pct | floor) \(.w) \(.v.resets)"' "$cache") || exit 0
read -r warn triage block model < <(jq -r \
  '"\(.thresholds.warn) \(.thresholds.triage) \(.thresholds.block) \(.model)"' "$config")

[ "$pct" -ge "$warn" ] || exit 0

when=$(date -d "$resets" '+%a %H:%M' 2>/dev/null || echo "?")
status="Claude $window limit at ${pct}% (resets $when)."
cheaper="Switch to a cheaper model: /model sonnet or /model haiku."
override="Start the prompt with !urgent to send it anyway."

say() { jq -n --arg m "$1" '{ systemMessage: $m }'; exit 0; }
hold() { jq -n --arg r "$1" '{ decision: "block", reason: $r }'; exit 0; }

prompt=$(jq -r '.prompt // ""' <<<"$input")
case "$prompt" in
  '!urgent'*) say "$status Sent as urgent. $cheaper" ;;
esac

[ "$pct" -ge "$triage" ] || say "$status $cheaper"
[ "$pct" -lt "$block" ] || hold "$status Held to save what's left. $override"

triagePrompt="You gate prompts sent to a coding assistant whose usage limit is nearly used up. \
Reply URGENT only if waiting a few hours would cause real harm: production is down, a security \
issue, a hard deadline today, or someone is blocked waiting on it. Everything else (features, \
refactors, cleanup, questions, exploration) is DEFER. Reply with exactly one word: URGENT or DEFER."

verdict=$(cd / && CLAUDE_LIMITS_INNER=1 timeout 30 claude -p --model "$model" \
  --no-session-persistence --setting-sources "" --tools "" \
  --system-prompt "$triagePrompt" <<<"$prompt" 2>/dev/null \
  | grep -oE 'URGENT|DEFER' | head -n1) || verdict=""

case "$verdict" in
  DEFER) hold "$status $model judged this can wait for the reset. $override" ;;
  URGENT) say "$status $model judged this urgent, so it went through. $cheaper" ;;
  *) say "$status Couldn't triage this prompt, so it went through. $cheaper" ;;
esac
