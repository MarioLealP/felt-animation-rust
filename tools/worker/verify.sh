#!/usr/bin/env bash
# verify.sh <order-id> - compiler feedback for a finished felt-animation-rust order, without giving the worker a shell.
# 1. refuse code that could run at build time (build.rs, proc-macro, build-deps) or deps outside the allowlist
# 2. cargo fetch with network (runs no crate code), cargo fmt (formatter only)
# 3. cargo test + clippy in an unshare jail: no network, secrets and Windows drives hidden
# 4. on failure resume the SAME worker session with the errors, max ROUNDS times; commit each round
# Result: runs/<id>.verify.txt (first line PASS/FAIL/REFUSED).
set -uo pipefail
id=$1; HERE=~/felt-work; w=$HERE/wt/$id; RUNS=$HERE/runs; out=$RUNS/$id.verify.txt; ROUNDS=${ROUNDS:-2}
ALLOWED="serde serde_json toml thiserror rand regex"

pkgs() { # package names of the crates this order added
  git -C "$w" diff --name-only main..HEAD | grep -E '^crates/[^/]+/Cargo.toml$' | while read -r f; do
    python3 -I -c 'import sys,tomllib; print(tomllib.load(open(sys.argv[1],"rb"))["package"]["name"])' "$w/$f"
  done
}

safety() { # prints problems; empty = ok
  git -C "$w" diff --name-only main..HEAD | grep -vE '^crates/' | sed 's/^/file outside crates\/: /'
  find "$w/crates" -name build.rs | sed 's/^/build script: /'
  git -C "$w" diff --name-only main..HEAD | grep -E '^crates/[^/]+/Cargo.toml$' | while read -r f; do
    python3 -I - "$w/$f" "$ALLOWED" <<'EOF'
import sys, tomllib
t = tomllib.load(open(sys.argv[1], "rb")); ok = set(sys.argv[2].split())
if t.get("lib", {}).get("proc-macro"): print("proc-macro crate")
if "build" in t.get("package", {}): print("package.build set")
if t.get("build-dependencies"): print("build-dependencies present")
for sec in ("dependencies", "dev-dependencies"):
    for name, spec in t.get(sec, {}).items():
        if name not in ok and not (isinstance(spec, dict) and spec.get("workspace")): print(f"{sec}: {name} not allowed")
        if isinstance(spec, dict) and ({"git", "path"} & spec.keys()): print(f"{sec}: {name} git/path source")
EOF
  done
}

jail() { # run "$@" in $w: own user+mount+net namespaces, no network, secrets/drives hidden by empty tmpfs
  unshare -Urmn bash -c '
    for d in "$HOME/.ssh" "$HOME/.config" "$HOME/.claude" "$HOME/.claude-work" "$HOME/.claude-worker" \
             "$HOME/.local" "$HOME/src" /mnt/c /mnt/e /mnt/f; do [ -d "$d" ] && mount -t tmpfs none "$d"; done
    for f in "$HOME/.claude.json" "$HOME/.cargo/credentials" "$HOME/.cargo/credentials.toml" "$HOME/.git-credentials" "$HOME/.bash_history"; do [ -f "$f" ] && mount --bind /dev/null "$f"; done
    cd "$0" && exec "$@"' "$w" "$@"
}

check() { # writes errors to $1, returns 0 when all green
  local log=$1; : > "$log"
  local p args=(); for p in $(pkgs); do args+=(-p "$p"); done
  [ ${#args[@]} -gt 0 ] || { echo "no crate was created" > "$log"; return 1; }
  (cd "$w" && cargo fetch -q) >> "$log" 2>&1 || return 1
  (cd "$w" && cargo fmt "${args[@]}") >> "$log" 2>&1
  jail cargo test --offline -q "${args[@]}" > "$log.test" 2>&1; local t=$?
  jail cargo clippy --offline -q "${args[@]}" --all-targets -- -D warnings > "$log.clippy" 2>&1; local c=$?
  [ $t -eq 0 ] || { echo "### cargo test failed"; grep -vE '^\s*(Compiling|Running|Finished|Downloaded)' "$log.test" | head -120; } >> "$log"
  [ $c -eq 0 ] || { echo "### cargo clippy -D warnings failed"; head -120 "$log.clippy"; } >> "$log"
  grep -E '^test result: ok. [1-9]' "$log.test" > "$out.tests"
  rm -f "$log.test" "$log.clippy"
  [ $t -eq 0 ] && [ $c -eq 0 ]
}

commit() { git -C "$w" add -A && { git -C "$w" diff --cached --quiet || git -C "$w" commit -q -m "$1"; }; }

: > "$out.tests"
bad=$(safety)
if [ -n "$bad" ]; then printf 'REFUSED (not built)\n%s\n' "$bad" > "$out"; exit 1; fi
sid=$(jq -r 'select(.session_id) | .session_id' "$RUNS/$id.jsonl" | head -1)
for round in $(seq 0 "$ROUNDS"); do
  if check "$RUNS/$id.check.log"; then commit "order $id: cargo fmt"; { echo "PASS (fix rounds: $round)"; cat "$out.tests"; } > "$out"; exit 0; fi
  commit "order $id: cargo fmt"
  [ "$round" -lt "$ROUNDS" ] || break
  (cd "$w" && claude-worker -t 80 -- --resume "$sid" "The dispatcher built your crate outside your sandbox. It does NOT pass yet. \
Fix ONLY these errors, inside your crate, without changing what the tests assert (unless a test itself is wrong vs the \
Python - then say so). You still cannot run cargo; it will be re-run for you. Errors:
$(cat "$RUNS/$id.check.log")") >> "$RUNS/$id.fix.jsonl" 2>> "$RUNS/$id.err"
  jq -r 'select(.type=="result") | .result' "$RUNS/$id.fix.jsonl" | tail -1 > "$RUNS/$id.fix$((round+1)).txt"
  new=$(safety); [ -z "$new" ] || { printf 'REFUSED after fix round %s\n%s\n' "$((round+1))" "$new" > "$out"; exit 1; }
  commit "order $id: fix round $((round+1))"
done
{ echo "FAIL after $ROUNDS fix rounds"; cat "$RUNS/$id.check.log"; } > "$out"; exit 1
