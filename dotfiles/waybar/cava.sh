# Waybar sound bars for both the speakers and the mic, drawn by the standalone cava.
# Two cava runs (cava.conf: what's playing; cava-mic.conf: the mic) each print a
# frame of bar heights 0–7 ("0;3;7;…"); every bar shows the louder of the two and
# becomes ▁…█. Aqua when the mic is the louder one, orange otherwise, dim in silence.
# (Waybar's built-in cava module draws a fixed pattern on this machine.)
#
#   waybar-cava OUT_CONF MIC_CONF   run (Waybar's exec)
#   waybar-cava toggle              switch it off — cava stops, closing the mic — or on

state="${XDG_RUNTIME_DIR:-/tmp}/waybar-cava"
mkdir -p "$state"

stop_cava() {
  if [ -s "$state/pids" ]; then
    # shellcheck disable=SC2046 # two PIDs, split on purpose
    kill $(cat "$state/pids") 2>/dev/null || true
  fi
  rm -f "$state/pids"
}

if [ "$1" = toggle ]; then
  if [ -e "$state/off" ]; then rm -f "$state/off"; else touch "$state/off"; fi
  stop_cava # the running loop notices and shows the new state
  exit 0
fi

out_conf="$1"
mic_conf="$2"
trap stop_cava EXIT
trap 'exit 0' TERM INT HUP

show() { # text class tooltip
  printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' "$1" "$2" "$3"
}

while true; do
  if [ -e "$state/off" ]; then
    show "󰝛" off "Sound bars are off\\nClick to turn them on"
    while [ -e "$state/off" ]; do sleep 1; done
    continue
  fi

  # The mic's conf names its source: fill in today's default mic.
  mic=$(wpctl inspect @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | sed -n 's/.*node\.name = "\(.*\)"/\1/p' | head -1)
  sed "s|@SOURCE@|${mic:-auto}|" "$mic_conf" >"$state/mic.conf"

  # pdeathsig: the kernel stops cava when this script dies, however it dies.
  exec {out_fd}< <(exec setpriv --pdeathsig TERM cava -p "$out_conf" 2>/dev/null)
  out_pid=$!
  exec {mic_fd}< <(exec setpriv --pdeathsig TERM cava -p "$state/mic.conf" 2>/dev/null)
  echo "$out_pid $!" >"$state/pids"

  mic_frame=""
  last=""
  # Paced by the speakers' cava (30 frames a second, sound or not).
  while IFS= read -r -u "$out_fd" frame; do
    [[ "$frame" =~ ^[0-9\;]+$ ]] || continue # cava also prints a title escape
    out_frame=${frame//;/}
    # Take the mic's latest frame without waiting for it.
    while IFS= read -r -t 0.001 -u "$mic_fd" frame; do
      if [[ "$frame" =~ ^[0-9\;]+$ ]]; then mic_frame=${frame//;/}; fi
    done

    bars="" out_sum=0 mic_sum=0
    for ((i = 0; i < ${#out_frame}; i++)); do
      a=${out_frame:i:1} b=${mic_frame:i:1}
      b=${b:-0}
      if ((b <= 1)); then b=0; fi # the mic always hears a little room noise
      out_sum=$((out_sum + a)) mic_sum=$((mic_sum + b))
      if ((b > a)); then bars+="$b"; else bars+="$a"; fi # append the digit
    done

    if ((out_sum + mic_sum == 0)); then
      class=silent
    elif ((mic_sum > out_sum)); then
      class=mic
    else
      class=out
    fi
    bars=${bars//0/▁} bars=${bars//1/▂} bars=${bars//2/▃} bars=${bars//3/▄}
    bars=${bars//4/▅} bars=${bars//5/▆} bars=${bars//6/▇} bars=${bars//7/█}
    # In silence the frame doesn't change: skip redrawing the same bars 30 times a second.
    if [ "$bars$class" != "$last" ]; then
      show "$bars" "$class" "Speakers and mic\\nClick to turn the bars off"
      last="$bars$class"
    fi
  done
  exec {out_fd}<&- {mic_fd}<&-
  stop_cava
  # cava stopped: switched off, or PipeWire restarted (e.g. on a rebuild). Go again.
  sleep 1
done
