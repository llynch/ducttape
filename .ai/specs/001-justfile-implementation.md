# 001 - Ducttape: Python to Just Migration (docker containers)

## Goal
Replace the `d` (docker containers) command in ducttape's Python `main.py`
with a `just`-based implementation, using just's module system to mirror the
CLI's `<command> <alias>` structure with real files/folders.

## Scope
- Port only `d` (docker containers) in this pass.
- `di`, `dv`, `dvv`, `dn`, `ds`, `gb`, `k`, `m`, `p`, `s`, `t`, `a` stay on Python,
  untouched.
- `main.py` and `requirements-dev.txt` are kept as-is (not deleted).

## Structure
```
ducttape/
  justfile          # root: `mod d`
  lib/fzf.just      # shared private `_fzf` helper (fzf flags/header)
  d/justfile        # docker container recipes
  aliases.sh        # `d` alias updated to call just instead of main.py
```

## `d/justfile` design
- `_ps` (private): `docker ps -a --format=...` listing, same columns/sort as
  `main.py`'s `COMMANDS["d"]`. Go-template braces escaped for just's `{{ }}`.
- `_pick *flags` (private): `_ps` piped through shared `_fzf` helper, forwards
  extra fzf flags (e.g. `-1` for single-select).
- Public recipes, one per existing alias: `logs`, `sh`, `exec *cmd`, `start`,
  `stop`, `inspect`, `restart`, `rm`, `rmf`. Each: `just _pick [...] | while
  read -r id _; do docker <cmd> "$id" ...; done`.

## Aliases
Only the `d` alias changes:
```bash
alias d='just --justfile "${DUCTTAPE_DIR}/justfile" d'
```
All other aliases keep calling `main.py`.

## Testing rules (no side effects)
- Never touch containers/images/volumes/networks already running or existing
  on the host.
- For any destructive recipe (`rm`, `rmf`, `stop`, `restart`), create a
  disposable test resource first (e.g. `docker run -d --name ducttape-test ...`),
  validate against it, then clean it up. Same principle applies later to
  images (`di`), volumes (`dv`/`dvv`), networks (`dn`), services (`ds`).

## Verification
- `just --list --list-submodules` shows `d`'s public recipes only (private
  `_ps`/`_pick` hidden).
- Manually run `just d logs`, `just d sh`, `just d exec -- bash`, `just d rm`,
  etc. against the disposable test container.
- `source aliases.sh` and confirm `d` works from the shell.
