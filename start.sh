#!/bin/bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

for _ in $(seq 50); do
  pgrep -x fbi >/dev/null || break
  sleep 0.1
done

cd $SCRIPT_DIR/recordings
love ../love