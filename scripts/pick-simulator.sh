#!/usr/bin/env bash
# Prints the UDID of an available simulator whose name starts with $1 (iPhone|iPad), on the newest iOS runtime.
set -euo pipefail
family="${1:-iPhone}"
xcrun simctl list devices available -j | python3 -c '
import json, re, sys
family = sys.argv[1]
devices = json.load(sys.stdin)["devices"]
def version(runtime):
    m = re.search(r"iOS-(\d+)-(\d+)", runtime)
    return (int(m.group(1)), int(m.group(2))) if m else (0, 0)
for runtime in sorted((r for r in devices if "iOS" in r), key=version, reverse=True):
    for d in devices[runtime]:
        if d["name"].startswith(family) and d.get("isAvailable", True):
            print(d["udid"]); sys.exit(0)
sys.exit("no %s simulator found" % family)
' "$family"
