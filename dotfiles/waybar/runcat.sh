# Waybar cat, after the GNOME RunCat extension (github.com/win0err/gnome-runcat):
# runs faster the busier the CPU is, naps below the idle threshold, turns red past 80%.
# Streams one JSON line per frame; style.css (generated in desktop.nix) maps each
# class f0…fN / idle to its sprite. No forks in the loop: it runs all day.
frames="$1"
idle_threshold="$2"

# read -t on a pipe we also hold open for writing never sees EOF: a sleep without a fork.
exec {nap}<> <(:)

read_cpu() {
  local _ user nice system idle iowait irq softirq steal
  read -r _ user nice system idle iowait irq softirq steal _ </proc/stat
  total=$((user + nice + system + idle + iowait + irq + softirq + steal))
  busy=$((total - idle - iowait))
}

read_cpu
prev_total=$total prev_busy=$busy
usage=0 frame=0 tick=0 ms=220 delay=0.220

while true; do
  # Re-measure the CPU about twice a second, whatever the frame rate.
  if ((tick-- <= 0)); then
    read_cpu
    ((total > prev_total)) && usage=$((100 * (busy - prev_busy) / (total - prev_total)))
    prev_total=$total prev_busy=$busy
    # RunCat's curve: a full stride takes 250 + 850·(1 − cpu)² ms.
    ms=$(((250 + 850 * (100 - usage) ** 2 / 10000) / frames))
    printf -v delay '0.%03d' "$ms"
    tick=$((500 / ms))
  fi

  if ((usage < idle_threshold)); then
    class='"idle"'
  else
    class="\"f$frame\""
    ((usage >= 80)) && class+=',"hot"'
    frame=$(((frame + 1) % frames))
  fi
  printf '{"text":" ","class":[%s],"tooltip":"CPU %d%%\\nClick to open apps"}\n' "$class" "$usage"

  read -r -t "$delay" -u "$nap" _ || true
done
