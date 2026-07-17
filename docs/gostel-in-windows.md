# HANDOFF — Ghostel native module on Windows (kiennq fork migration)

## Goal
Get Ghostel (Emacs terminal emulator) working on Windows. Symptom: `M-x ghostel`
popped a modal — "Ghostel native module not found. [d] Download / [c] Compile /
[s] Skip" — that kept firing even though a DLL was present.

## Current Progress (as of 2026-05-31)
- **Root cause found and fixed on disk.** Config edited + matched DLLs installed.
- **Verified clean in isolated batch Emacs** (zero warnings, all native fns bound).
- **NOT yet active in the live daemon** — the running Emacs still has the OLD
  (dakra/MELPA) Elisp loaded. **A restart (or re-eval of config) is required.**
- If the `[d]/[c]/[s]` modal is still open in the daemon, press **`s`** to dismiss
  (neither `d` nor `c` helps — see below), then restart Emacs.

## Root Cause (corrected — first diagnosis was WRONG)
Two independent forks of Ghostel exist with **incompatible native module loaders**:
- **dakra/ghostel** (what MELPA `ghostel` package installs): loads
  `ghostel-module.dll` directly via `module-load`. Ships **NO Windows binaries**
  (only `.so`/`.dylib`). Its `ghostel--module-platform-tag` maps `windows-nt → nil`,
  so `ghostel-download-module` builds a `nil` URL → silently fails on Windows.
- **kiennq/ghostel** (the fork): uses a **split loader** — entry point is
  `dyn-loader-module.dll`, which loads `ghostel-module.dll` + `conpty-module.dll`
  (Windows ConPTY backend) as managed submodules via a manifest. Fixes the
  platform-tag bug (`windows-nt → "windows"`). Ships `x86_64-windows.tar.xz`.

The machine had a **kiennq DLL but dakra Elisp** → DLL loaded but registered ZERO
functions (wrong loader). Note: the Emacs binary itself is `emacs-31-mps-kiennq`.

**Secondary self-inflicted bug:** an earlier step in this session copied a stale
`0.30.0` `ghostel-module.version` sidecar over the real `0.31.0` marker. The loader
trusts the sidecar to decide whether to map the DLL without loading it, so a wrong
sidecar = self-inflicted "module too old, refuse to load" verdict. Fixed by
reinstalling fresh tarball files.

## What Worked
- Querying the **live daemon** (`mcp__anvil__emacs-eval`) to see real state instead
  of trusting the README — revealed `(featurep 'ghostel-module)=t` but
  `ghostel--module-version` unbound, exposing the loader mismatch.
- **GitHub API** (`api.github.com/repos/{dakra,kiennq}/ghostel/releases`) to see
  which repo actually ships Windows binaries (only kiennq does).
- **Isolated `emacs --batch -Q`** load tests — safe way to load an unknown native
  module without risking a segfault in the live daemon. (A bad native module can
  crash the whole Emacs process.)
- Reading the **cloned kiennq `ghostel.el`** directly (lines 1016-1178) to learn the
  dyn-loader architecture, the `0.31.0` min version, and that
  `ghostel--effective-module-dir` honors BOTH `ghostel-module-dir` AND
  `ghostel-module-directory`.
- Inspecting the **packed `.version` inside a freshly-downloaded tarball** to prove
  the real module version is `0.31.0` (binary was fine; only the sidecar was wrong).

## What Didn't Work / Dead Ends (don't repeat)
- **First conclusion "the module works, just run M-x ghostel" was WRONG** — the
  bundled dakra DLL was missing `ghostel--new`, `--write-input`, `--set-size`.
- `module-load`-ing `ghostel-module.dll` directly in batch → 0 functions. WRONG
  file for kiennq fork; the entry point is `dyn-loader-module.dll`, and the real
  load path is the Elisp's `ghostel--load-module` (don't hand-`module-load`).
- dakra release URLs for `x86_64-windows.dll` → all **404** (no such asset).
- The `Bash` tool reset its cwd and `curl` failed mid-run; **PowerShell**
  (`Invoke-WebRequest` / `Invoke-RestMethod` / `tar`) worked reliably.
- Batch `require 'ghostel'` can **hang under `--batch`** (dyn-loader spawns a helper
  that doesn't exit). Use a short timeout / run_in_background; don't block on it.
- `ghostel-reload-module` and `ghostel-module-dir` are in the README but the
  README tracks `main` and drifts from releases — verify against installed code.

## Changes Made (all on disk, verified)
| Change | Location |
|---|---|
| Cloned kiennq/ghostel `@v0.31.0.79.a7b0c9` (detached tag) via async-installer | `~/.emacs.d/external-packages/ghostel/` |
| Registered in async-installer (idempotent) | `(async-installer-git-add "https://github.com/kiennq/ghostel.git" :tag "v0.31.0.79.a7b0c9" :subdir "lisp" :main "ghostel.el")` |
| Installed matching Windows DLLs (dyn-loader + ghostel + conpty + .json + .version) | `~/.emacs.d/ghostel-module/` (sidecar now `0.31.0`) |
| `:ensure t` → `:ensure nil` + `:load-path "external-packages/ghostel/lisp"` | `lisp/init-local-shell.el:42` |
| Removed dead `GHOSTEL_SH_INTEGRATION` block (fork has built-in `ghostel-shell-integration`, default `t`; old `etc/shell/ghostel.zsh` path doesn't exist in clone's lisp/ layout) | `lisp/init-local-shell.el` `:config` |
| Kept: Windows `ghostel-module-directory` pin, Hel-sync hook, M-v binds | unchanged |
| **Shell config (Windows): set `ghostel-shell` to PowerShell 7 + added `ml/ghostel-bash` escape hatch** | `lisp/init-local-shell.el` `:init` |

## Shell Configuration (Windows) — added 2026-05-31, revised 2026-06-01
`ghostel-shell` (string or list `(program args...)`) selects the spawned shell; it
defaulted to `$SHELL`/cmdproxy.exe (cmd.exe). Now configured on Windows:
- **Default `M-x ghostel` → PowerShell 7:**
  `'("C:/Program Files/PowerShell/7/pwsh.exe" "-NoLogo")`.
  Chosen because pwsh is a **native Windows program**: it reports native `C:\`
  paths (no MSYS `/c/...` translation), which is what Claude Code and the native
  `git`/`rg` it spawns expect. Trade-off: **no OSC-133 shell integration** (pwsh
  is not bash/zsh/fish), so no prompt markers / directory tracking.
- **`M-x ml/ghostel-bash` → Git Bash:** escape hatch for unix-y interactive work.
  Resolves `bash.exe` via `executable-find` (i.e. from `$PATH`) and `let`-binds
  `ghostel-shell` to `(list <resolved-bash> "-l" "-i")`, then calls `ghostel`.
  Detected as `bash` by `ghostel--detect-shell`, so **shell integration applies**.
  No-ops with a `user-error` if bash isn't on `$PATH`.
  **CRITICAL:** put Git Bash's `usr\bin` (the real `bash.exe`) on `$PATH`, NOT
  `git-bash.exe` (a mintty GUI launcher that opens its own external window and
  will NOT render inside the Ghostel buffer). `bin\bash.exe` is a thin shim —
  works but indirect.

PowerShell 7 = `C:/Program Files/PowerShell/7/pwsh.exe`.

## Verification (isolated batch, passed)
`ghostel--new`, `--write-input`, `--set-size`, `--redraw`, `conpty--init` all bound ·
`modver=0.31.0 = minver=0.31.0` · **zero warnings** · `M-x ghostel` command exists ·
`init-local-shell.el` parens balanced (66 top-level forms, no scan errors).

## Next Steps
1. **Restart Emacs** (or re-eval `lisp/init-local-shell.el`) so the live daemon
   loads the kiennq Elisp. Then run `M-x ghostel` — should open with no modal,
   landing at a **PowerShell 7** prompt. `M-x ml/ghostel-bash` → Git Bash.
   NOTE: in the CURRENT live daemon the old dakra Elisp is still loaded, so the
   terminal may not render until restart — that's the module-load issue, NOT the
   shell config (shell config is verified correct by the resolver regardless).
2. **Optional cleanup:** the old MELPA `ghostel` package is still in
   `~/.emacs.d/elpa-31.0/ghostel-20260528.712/` but now UNUSED. Safe to
   `M-x package-delete` it to avoid confusion. (Left in place per surgical-changes.)
3. **On future kiennq version bumps:** re-pin the `:tag` in the async-installer call
   AND re-download the matching `ghostel-module-x86_64-windows.tar.xz`, extracting
   all 6 files into `~/.emacs.d/ghostel-module/`. Elisp min-version and the DLL's
   packed `.version` sidecar MUST match or the loader refuses to map the module.
4. **`.load.*.dll` files** in `~/.emacs.d/ghostel-module/` are dyn-loader runtime
   copies (it loads a hashed copy so the original can be swapped while mapped).
   Harmless; can be deleted, regenerated on next load.

## Key Paths / Facts
- Emacs binary: `C:\Users\ken\emacs-31-mps-kiennq\bin\emacs.exe` (kiennq build)
- Clone: `C:\Users\ken\.emacs.d\external-packages\ghostel\lisp\ghostel.el`
- Module dir (pinned, Windows-only): `C:\Users\ken\.emacs.d\ghostel-module\`
- Config: `C:\Users\ken\.emacs.d\lisp\init-local-shell.el` (ghostel block @ ~L42)
- kiennq min module version: `0.31.0` (`ghostel--minimum-module-version`)
- Latest kiennq release: `v0.31.0.79.a7b0c9` (module reports `0.31.0`)
