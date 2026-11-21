#!/bin/bash
clear
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# *should* prevent issues with crashing on hotplug
for _ in $(seq 150); do
  pgrep -x fbi >/dev/null || break
  sleep 0.2
done

sleep 2
cd "$SCRIPT_DIR/recordings"
love ../love