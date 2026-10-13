# MiMo worker pipeline (desktop WSL)

Used for the 2026-10-13 batch (28 ports + 7 skins). Run from `~/felt-work/` (scripts assume that layout:
`runs/`, `wt/`, the repos as siblings). Details + lessons: `F:\workspace\runbooks\felt-desktop-rust-port.md`.

- `dispatch.sh <repo> <order-id>...` - worktree + branch `order/<id>` per order, reference copied into
  `<wt>/ref/` (read-only, git-excluded; the worker sandbox only reads its cwd), order paths `~/ref/` -> `ref/`,
  runs `claude-worker`, commits the result (workers may not commit). `MAX` = parallel workers.
- `verify.sh <id>` - refuses build.rs / proc-macro / build-deps / deps outside `ALLOWED`; `cargo fetch` + `fmt`;
  `cargo test` + `clippy -D warnings` inside an `unshare -Urmn` jail (no network; ~/.ssh, ~/.config, ~/.claude*,
  ~/.local, ~/src, /mnt/c|e|f, credential files hidden); on failure resumes the same worker session with the
  errors, max `ROUNDS` (2). Result `runs/<id>.verify.txt` = PASS / FAIL / REFUSED.
- `verify-loop.sh` - runs verify.sh on every finished port order, `MAX` (3) at a time.
- `tokens.sh` - token totals from the run logs.

Workers never get cargo/python themselves: anything they write runs only inside the jail.
