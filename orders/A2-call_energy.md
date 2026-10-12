# Order A2-call_energy: port felt-animation's `call_energy` module to Rust

You are in a git worktree of the cargo workspace `felt-animation-rust`. Port ONE Python module.

- Source (read-only): `~/ref/felt-animation/src/felt_animation/signals/call_energy.py`
- Its tests (the spec): `~/ref/felt-animation/tests/test_signals_call_energy.py` (and any other test file that imports `call_energy` - grep).
- Data files it reads (if any) are in `~/ref/felt-animation/` (e.g. *.json, *.toml): read them, do not copy them.

## Create ONLY
- `crates/call-energy/Cargo.toml` (package name `felt-call-energy`, `edition.workspace = true`, `[lints] workspace = true`)
- `crates/call-energy/src/lib.rs` (+ more files under that crate's `src/` if needed)
- `crates/call-energy/tests/*.rs` - every Python test ported as a Rust test (same names, snake_case), same assertions.
Do not edit any file outside `crates/call-energy/`.

## Rules
- Behaviour identical to the Python. Same constants, same edge cases. Keep the doc comments meaningful.
- If the module imports another felt_animation module, do NOT port that one: define the minimal types/traits you
  need inside this crate, and list them in your report under "Shared types needed".
- Pure logic only. Win32/OS calls (ctypes, winsound, WMI...) -> a trait with no implementation; note it in the report.
- Clocks/randomness must be injectable (traits or function args) so tests are deterministic.
- Dependencies: only well-known crates (serde, serde_json, toml, thiserror, rand) and only if needed.
- No unsafe. No println in library code.

## Done when (run from the workspace root)
- `cargo nextest run -p felt-call-energy` passes (or `cargo test -p felt-call-energy`)
- `cargo clippy -p felt-call-energy --all-targets -- -D warnings` is clean
- `cargo fmt -p felt-call-energy` applied
Stop after 3 failed fix attempts on the same error; report it.

## Report (final message)
Tests ported (count, Python vs Rust), anything not ported and why, shared types needed, OS traits left unimplemented.
