#!/usr/bin/env bash
# verify-loop.sh - run verify.sh on every finished felt-animation-rust order (A*), MAX at a time, until all are verified.
cd ~/felt-work/runs || exit 1; MAX=${MAX:-3}; TOTAL=$(ls ../felt-animation-rust/orders/*.md | wc -l)
while true; do
  for f in A*.done; do
    [ -e "$f" ] || continue; id=${f%.done}
    [ -e "$id.verify.txt" ] || [ -e "$id.verifying" ] && continue
    while [ "$(jobs -rp | wc -l)" -ge "$MAX" ]; do wait -n; done
    touch "$id.verifying"; (../verify.sh "$id"; rm -f "$id.verifying"; echo "VERIFIED $id: $(head -1 "$id.verify.txt")") &
  done
  [ "$(ls A*.verify.txt 2>/dev/null | wc -l)" -ge "$TOTAL" ] && { wait; echo "ALL $TOTAL VERIFIED"; exit 0; }
  sleep 20
done
