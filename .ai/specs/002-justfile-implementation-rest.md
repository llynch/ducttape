# 002 - Ducttape: Python to Just Migration (remaining commands)

## Goal
Finish the migration started in 001 by porting every remaining command from
`main.py` to `just` modules, then retire the Python implementation entirely.

## Amends 001
Spec 001 stated `di`, `dv`, `dvv`, `dn`, `ds`, `gb`, `k`, `m`, `p`, `s`, `t`, `a`
"stay on Python, untouched" and that `main.py` / `requirements-dev.txt` are
"kept as-is (not deleted)". Both statements are superseded here: all commands
move to just, and the Python implementation is removed.

## Scope
- Port the 12 remaining commands to just modules.
- Delete `main.py`, `requirements-dev.txt`, and `Makefile` (ruff-only, dead once
  there is no Python left).
- Keep the user-facing CLI byte-identical: same command names, same alias names.

## Structure
```
ducttape/
  justfile          # root: `mod` per command + `default` usage recipe
  lib/fzf.just      # shared private `_fzf` helper (unchanged)
  d/justfile        # from 001
  di/ dv/ dvv/ dn/ ds/ gb/ k/ m/ p/ s/ t/ a/
  aliases.sh        # every alias calls just
```

## Module pattern (from 001)
Each module: `import '../lib/fzf.just'`, a private listing recipe, a private
`_pick` that pipes the listing through `_fzf`, and one public recipe per alias
that already exists in `main.py`. Public recipes loop
`| while read -r ... ; do <cmd>; done` so multi-select keeps working.

`-1` (single-select) is passed to `_pick` for inherently interactive or
single-target recipes (`exec`, `tmux attach`).

## Command mapping
Field indices are taken from `main.py`'s `COMMANDS` extraction table.

| Module | Source                                          | Field(s)          | Recipes |
|--------|-------------------------------------------------|-------------------|---------|
| `di`   | `docker image ls \| sed 1d`                     | id (col 2)        | `rm`, `rmf` |
| `dv`   | `docker volume ls \| sed 1d`                    | name (col 1)      | `rm`, `rmf`, `inspect` |
| `dvv`  | `docker system df -v` volume section            | name (col 0)      | `rm`, `rmf`, `inspect` |
| `dn`   | `docker network ls \| sed 1d`                   | id (col 0)        | `rm`, `rmf`, `inspect` |
| `ds`   | `docker service ls \| sed 1d`                   | name (col 1)      | `logs`, `rm`, `rmf`, `inspect`, `scale0`, `scale1`, `start`, `stop`, `restart` |
| `gb`   | `git branch -a \| sed 's/[\* ]*//'`             | branch (col 0)    | `c`, `co`, `track`, `lg`, `diff` |
| `k`    | `kubectl get --all-namespaces pods`             | ns (0) + pod (1)  | `logs`, `logs0`, `exec`, `k` |
| `m`    | `Makefile` target parse (awk)                   | target (col 0)    | `m` |
| `p`    | `ps -ef`                                        | pid (col 1)       | `k`, `kill`, `k9` |
| `s`    | `sudo service --status-all`                     | name (col 3)      | `restart`, `status`, `start`, `stop` |
| `t`    | `tmux ls \| sed 's/:/ /'`                       | session (col 0)   | `a` |
| `a`    | `apt list \| sed 's_/_ _'`                      | package (col 0)   | `i`, `install`, `r`, `remove` |

## Working directory (`gb`, `m`)
just runs a module recipe with `pwd` set to the *module* directory, so a naive
port of `gb`/`m` would read ducttape's own git repo / Makefile instead of the
user's. Verified behaviour:

- `invocation_directory()` returns the user's cwd.
- A nested `just` call **resets** `invocation_directory()` to the module dir.
- `set working-directory := invocation_directory()` is rejected
  ("Cannot call functions in const context").

Solution used in `gb` and `m`:
- `dir := invocation_directory()` at module top.
- `dir` is passed explicitly as an argument through nested `just` calls.
- Never `cd` before invoking a nested `just` (it would resolve the *user's*
  justfile); `cd '{{dir}}'` only inside a subshell around the real command.

All other modules act on global state (docker daemon, kube context, process
table, tmux server, apt) and are cwd-independent.

## Deviations from `main.py`
- **apt remove bug fixed**: `main.py` maps `r`/`remove` to `sudo remove install`
  (nonsense). Now `sudo apt remove`.
- **Header rows stripped** for `dvv`, `k`, `p`. `main.py` left the column header
  in the fzf list as selectable noise; `sed 1d` removes it, matching how `d`,
  `di`, `dv`, `dn`, `ds` already drop theirs. No interface change.
- Everything else (alias names, flags, command strings, `sudo` on `s`) is
  preserved verbatim, including `docker network rm -f`.

## Pre-existing bugs found and fixed during the port
1. **`di` targeted the wrong column.** `main.py` hardcoded index 2 for the image
   id, assuming `REPOSITORY TAG IMAGE_ID CREATED SIZE`. Current docker prints
   `IMAGE ID DISK-USAGE CONTENT-SIZE EXTRA` (repository and tag merged), so
   index 2 resolved to the *size* (e.g. `1.81GB`). Fixed by giving `di`, `dv`,
   `dn`, `ds` explicit `--format='table ...'` strings (as `d` already did in
   001), making column positions version-stable instead of positional guesses.
2. **`m` silently hid targets containing `t`.** The awk class
   `[^\$$#\/\\t=]` contained a literal `\` and `t` rather than a tab escape, so
   any target with `t` after the first character (`lint`, `test`, `install`)
   never appeared. Fixed to `[^$#\/\t=]`. Ducttape's own `Makefile` (`lint`,
   `lint-fix`) was invisible to `m` because of this.
3. **`DUCTTAPE_DIR` resolved to a file, not a directory.** `aliases.sh` used
   `realpath "${BASH_SOURCE[-1]}"`, yielding `.../aliases.sh`, so every alias
   built `.../aliases.sh/justfile`. `BASH_SOURCE[-1]` is also the *outermost*
   frame, so sourcing from `~/.bashrc` resolved to `~/.bashrc`. Fixed to
   `dirname "$(realpath "${BASH_SOURCE[0]}")"`, with a zsh fallback
   (`${(%):-%x}`) guarded by `eval` so bash never parses zsh-only syntax.

## Usage output
Bare `just` previously failed with "Justfile contains no recipes". The root
justfile gains a `default` recipe printing a usage line plus
`just --list --list-submodules`, so `dt` / `ducttape` keep showing help.

Each module also gets a `default` recipe (`@just --list`) as its **first**
recipe. just treats the first recipe in a file as the default, so without this
`just d` ran the private `_ps` listing and dumped raw `docker ps` output.
`just <command>` with no alias now prints that command's recipes instead.
Ordering matters: `default` must precede the private listing recipe.

## Aliases
All aliases call just:
```bash
alias dt='just --justfile "${DUCTTAPE_DIR}/justfile"'
alias <cmd>='just --justfile "${DUCTTAPE_DIR}/justfile" <cmd>'
```

## Testing rules (inherited from 001, no side effects)
- Never touch containers/images/volumes/networks/services already present on the
  host.
- For destructive recipes, create a disposable resource first (e.g.
  `docker volume create ducttape-test`), validate, then clean up.
- `p` (kill) and `s` (services) are validated by listing/`--dry-run`-style
  inspection only; never signal a real process or restart a host service.

## Verification
- `just --list --list-submodules` shows all 13 modules, public recipes only.
- Bare `just` prints usage.
- `source aliases.sh` and confirm each alias resolves (verified for direct,
  cross-directory, and indirect `.bashrc`-style sourcing).
- `gb`/`m` verified from a directory outside ducttape to prove cwd handling:
  `gb co` switched branches in a scratch repo, `m m` ran a target from that
  repo's Makefile.
- Destructive docker recipes (`dv rm`, `dn rm`, `di rm`) verified against
  purpose-built disposable resources, then confirmed removed with host
  volumes/networks/images/services otherwise untouched.
- fzf can be driven non-interactively for testing via
  `FZF_DEFAULT_OPTS="--filter=<pattern>"`.
- Not executable on this host (tools absent): `k` (no kubectl), `a` (no apt,
  Arch). `s` listing skipped to avoid a sudo prompt / touching host services.
