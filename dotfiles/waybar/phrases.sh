# Waybar custom module: shows one phrase from a list and rotates it every hour.
#
# I (haywan) built this to keep a dhikr in front of me all day. Put whatever
# you like in it — reminders, words you're learning, quotes.
#
# Usage: phrases <file> [pcre]
#   file  one phrase per line
#   pcre  optional: extract phrases from any text file with `grep -oP <pcre>`
#         e.g. '(?<=Say ")[^"]*' pulls the text out of every  Say "..."

file="${1:?usage: phrases <file> [pcre]}"
pattern="${2:-}"

if [ ! -r "$file" ]; then
  jq -nc --arg f "$file" '{text: "", tooltip: "phrases: \($f) not found"}'
  exit 0
fi

if [ -n "$pattern" ]; then
  mapfile -t items < <(grep -oP "$pattern" "$file" || true)
else
  mapfile -t items < <(grep -v '^[[:space:]]*$' "$file" || true)
fi

n=${#items[@]}
if [ "$n" -eq 0 ]; then
  echo '{"text":""}'
  exit 0
fi

# Same phrase for the whole hour; stepping by 7 walks through the entire list
# before repeating (as long as the list size isn't a multiple of 7).
hour=$(($(date +%s) / 3600))
phrase="${items[$(((hour * 7) % n))]}"

jq -nc --arg p "$phrase" '{text: $p, tooltip: $p, class: "phrases"}'
