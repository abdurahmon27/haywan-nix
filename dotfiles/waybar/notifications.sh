# Waybar bell: swaync's own Waybar feed, plus a "new" class for a few seconds
# whenever a notification arrives, so the bell rings once instead of glowing forever.

# Our own handle on swaync-client, so it goes away with us instead of
# lingering after Waybar restarts. The EXIT trap misses SIGKILL/SIGPIPE, so
# also have the kernel signal it when we die.
exec 3< <(exec setpriv --pdeathsig TERM swaync-client --subscribe-waybar)
feed=$!
trap 'kill "$feed" 2>/dev/null' EXIT
trap 'exit 0' TERM INT HUP PIPE

ring=3
prev=0
last=""
ringing=false

emit() {
  jq -c --argjson new "$1" \
    '.class |= ((if type == "array" then . else [.] end) + (if $new then ["new"] else [] end))' <<<"$last"
}

while :; do
  if $ringing; then t=$ring; else t=3600; fi
  if IFS= read -r -u 3 -t "$t" line; then
    last=$line
    count=$(jq -r '.text | tonumber? // 0' <<<"$line")
    class=$(jq -r '.class | if type == "array" then join(" ") else . end' <<<"$line")
    # No ringing in do-not-disturb.
    if [ "$count" -gt "$prev" ] && [[ "$class" != *dnd* ]]; then ringing=true; else ringing=false; fi
    prev=$count
    emit "$ringing"
  else
    # A timeout is >128; anything else means swaync-client quit, and Waybar restarts us.
    [ $? -gt 128 ] || exit 0
    ringing=false
    [ -z "$last" ] || emit false
  fi
done
