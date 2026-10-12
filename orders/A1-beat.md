# Order A1-beat: port felt-animation's `beat` module to Rust

You are in a git worktree of the cargo workspace `felt-animation-rust`. Port ONE Python module.

- Source (read-only): `~/ref/felt-animation/src/felt_animation/beat.py`
- Its tests (the spec): `~/ref/felt-animation/tests/test_beat.py` (and any other test file that imports `beat` - grep).
- Data files it reads (if any) are in `~/ref/felt-animation/` (e.g. *.json, *.toml): read them, do not copy them.

## Create ONLY
- `crates/beat/Cargo.toml` (package name `felt-beat`, `edition.workspace = true`, `[lints] workspace = true`)
- `crates/beat/src/lib.rs` (+ more files under that crate's `src/` if needed)
- `crates/beat/tests/*.rs` - every Python test ported as a Rust test (same names, snake_case), same assertions.
Do not edit any file outside `crates/beat/`.

## Rules
- Behaviour identical to the Python. Same constants, same edge cases. Keep the doc comments meaningful.
- If the module imports another felt_animation module, do NOT port that one: define the minimal types/traits you
  need inside this crate, and list them in your report under "Shared types needed".
- Pure logic only. Win32/OS calls (ctypes, winsound, WMI...) -> a trait with no implementation; note it in the report.
- Clocks/randomness must be injectable (traits or function args) so tests are deterministic.
- Dependencies: only well-known crates (serde, serde_json, toml, thiserror, rand) and only if needed.
- No unsafe. No println in library code.

## Done when (run from the workspace root)
- `cargo nextest run -p felt-beat` passes (or `cargo test -p felt-beat`)
- `cargo clippy -p felt-beat --all-targets -- -D warnings` is clean
- `cargo fmt -p felt-beat` applied
Stop after 3 failed fix attempts on the same error; report it.

## Report (final message)
Tests ported (count, Python vs Rust), anything not ported and why, shared types needed, OS traits left unimplemented.
