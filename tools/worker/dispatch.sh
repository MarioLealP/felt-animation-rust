#!/usr/bin/env bash
# dispatch.sh <repo-dir> <order-id>...  - run MiMo workers (claude-worker) on Felt orders, MAX in parallel.
# Each order: own worktree + branch order/<id>, the reference copied into <wt>/ref/ (git-excluded) because the
# worker sandbox only reads inside its cwd, prompt = the order with ~/ref/ rewritten to ref/. The worker may not
# commit, so this script commits its changes afterwards. Logs/reports in ~/felt-work/runs/.
set -uo pipefail
REPO=$(realpath "$1"); shift
HERE=~/felt-work; RUNS=$HERE/runs; WT=$HERE/wt; MAX=${MAX:-4}
PY=/mnt/f/workspace/Projects/felt-animation
MOCKS=~/src/clockmost-desktop/endfield-desktop-2026-10-10

copy_ref() { # $1 = worktree
  set -o pipefail
  mkdir -p "$1/ref"
  case $(basename "$REPO") in
    felt-animation-rust)
      mkdir -p "$1/ref/felt-animation"
      tar -C "$PY" -cf - --exclude __pycache__ --exclude .venv --exclude .git --exclude rhubarb --exclude scripts . \
        | tar -C "$1/ref/felt-animation" -xf - || return 1 ;;
    skins)
      mkdir -p "$1/ref/mocks/orders"
      tar -C "$MOCKS" -cf - components src/assets | tar -C "$1/ref/mocks" -xf - || return 1
      cp "$MOCKS/WORKLOG.md" "$1/ref/mocks/" && cp "$MOCKS/orders/STYLE.md" "$1/ref/mocks/orders/" || return 1 ;;
  esac
  chmod -R a-w "$1/ref"
}

run_one() { # $1 = order id
  local id=$1 w=$WT/$1
  git -C "$REPO" worktree add -q -b "order/$id" "$w" main || return 1
  copy_ref "$w" || { echo "ref copy failed: $id" >&2; return 1; }
  date -Is > "$RUNS/$id.started"
  (cd "$w" && claude-worker -t 200 "$(sed 's#~/ref/#ref/#g' "$REPO/orders/$id.md")") \
    > "$RUNS/$id.jsonl" 2> "$RUNS/$id.err"
  jq -r 'select(.type=="result") | .result' "$RUNS/$id.jsonl" > "$RUNS/$id.report.txt"
  git -C "$w" add -A
  git -C "$w" diff --cached --quiet || git -C "$w" commit -q -m "order $id (MiMo worker)"
  date -Is > "$RUNS/$id.done"
}

for id in "$@"; do
  while [ "$(jobs -rp | wc -l)" -ge "$MAX" ]; do wait -n; done
  run_one "$id" &
done
wait
echo "batch done: $*" >> "$RUNS/batches.log"
