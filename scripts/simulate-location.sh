#!/usr/bin/env bash
# Apply a location outside the app (run on the Mac).
#
#   scripts/simulate-location.sh simulator <lat> <lon>     # booted iOS Simulator
#   scripts/simulate-location.sh simulator --gpx file.gpx  # static point, or a route if the GPX has several waypoints
#   scripts/simulate-location.sh device <lat> <lon>        # physical device, iOS 17+ (pymobiledevice3)
#   scripts/simulate-location.sh device --gpx file.gpx     # first waypoint of the GPX
#   scripts/simulate-location.sh simulator|device clear    # stop simulating
#
# SIM_DEVICE=<udid|name> picks a simulator when several are booted (default: booted).
# Device mode needs `pip3 install pymobiledevice3` and a tunnel: `sudo pymobiledevice3 remote tunneld`.
set -euo pipefail
sim="${SIM_DEVICE:-booted}"

usage() { sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

target="${1:-}"; shift || true
[[ "$target" == "simulator" || "$target" == "device" ]] || usage
[[ $# -ge 1 ]] || usage

waypoints() {
    python3 - "$1" <<'PY'
import sys, xml.etree.ElementTree as ET
for el in ET.parse(sys.argv[1]).getroot().iter():
    if el.tag.split("}")[-1] == "wpt":
        print(f'{float(el.get("lat")):.6f},{float(el.get("lon")):.6f}')
PY
}

validate() {
    python3 -c 'import sys; la, lo = float(sys.argv[1]), float(sys.argv[2]); sys.exit(0 if -90 <= la <= 90 and -180 <= lo <= 180 else 1)' "$1" "$2" \
        || { echo "invalid coordinate: $1, $2" >&2; exit 2; }
}

points=()
case "$1" in
    clear)
        if [[ "$target" == simulator ]]; then xcrun simctl location "$sim" clear
        else pymobiledevice3 developer dvt simulate-location clear; fi
        exit 0 ;;
    --gpx)
        [[ -f "${2:-}" ]] || { echo "GPX file not found: ${2:-}" >&2; exit 2; }
        while IFS= read -r p; do points+=("$p"); done < <(waypoints "$2")
        [[ ${#points[@]} -gt 0 ]] || { echo "no <wpt> found in $2" >&2; exit 2; } ;;
    *)
        [[ $# -eq 2 ]] || usage
        points=("$1,$2") ;;
esac

for p in "${points[@]}"; do validate "${p%,*}" "${p#*,}"; done
first="${points[0]}"

if [[ "$target" == simulator ]]; then
    if [[ ${#points[@]} -gt 1 ]]; then
        xcrun simctl location "$sim" start --interval=5 "${points[@]}"
    else
        xcrun simctl location "$sim" set "$first"
    fi
else
    pymobiledevice3 developer dvt simulate-location set -- "${first%,*}" "${first#*,}"
fi
echo "Simulating ${first} on ${target}"
