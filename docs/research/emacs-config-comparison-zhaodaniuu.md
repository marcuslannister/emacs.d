# Emacs config comparison: this repo (A) and zHaOdANiuu/.emacs.d (B)

Date: 2026-10-09. Method: read the config files in both repos. Read Emacs 31.1 docstrings and `startup.el` for built-in behavior. No package upstream docs were fetched.

- A = `~/Projects/emacs.d` (paths are relative to that root).
- B = `~/github/zHaOdANiuu/.emacs.d` (paths are relative to that root).
- Line numbers are from the files as read on this date.
- "Not confirmed" marks a claim I could not verify in a primary source.

## 1. Structure and loading

| Topic | A | B |
|---|---|---|
| Base | Purcell-style config (`sanityinc/` names). `init.el:1-6` | Own design with an `nn-` prefix. `nn.el:6-8` |
| Module dir | `lisp/init-*.el`, added to `load-path` at `init.el:92` | `user-lisp/init-*.el`. Emacs 31 `user-lisp-directory` puts it on `load-path` |
| Module count | About 100 files in `lisp/` | 11 files: builtin, display, editor, debug, lang, vc, terminal, utils, www, keybind, home (`init.el:16-26`) |
| Loader | Plain `(require 'init-x)` list in `init.el:117-257`. Many lines are commented out (for example haskell, ruby, sql) | One `(require ...)` block inside `let ((file-name-handler-alist nil))` (`init.el:15-26`) |
| Local layer | `init-local.el` is loaded last (`init.el:275`). It adds Hel, GTD, shell, AI, macOS or Windows files | None. Everything is in the 11 files |
| Third-party code | `site-lisp/` holds only a README. Git packages use a custom `async-installer` (`lisp/package-list.el:12-70`, `lisp/init-local-async-installer.el`) into `external-packages/` | Own packages live in `user-lisp/` (live-server, simple-mpv, elegant-world, hideshow-savefold). Others use `:vc` (`user-lisp/init-vc.el:126`, `init-lang.el:21`, `init-display.el:242`) |
| Tests | `tests/*.el` (ERT) for local modules; `AGENTS.md` asks for `./test-startup.sh` | No test directory found |
| State dir | `custom.el`, `elpa-31.1/` (`init-elpa.el:10-12`) | One `nn-directory` for project list, backups, tramp, org ids (`nn.el:10`, `init-builtin.el:14,53`) |

Notes:

- B's `user-lisp-auto-scrape` is nil (`early-init.el:83`). Emacs then calls `prepare-user-lisp` with `just-activate` set (`startup.el:1569-1572` in Emacs 31.1). So the directory goes on `load-path` with no compile or autoload scan.
- B sets `nn-directory` to `~/.emacs.d/var/` (`nn.el:10`), but its README says state is under `.nn/` (`README.org:19,85`). The two do not match. Not confirmed which is current.
- B also sets `lexical-binding` default to nil (`early-init.el:8`). This is a risky choice that I did not test.

## 2. Package manager and package list

### Package manager

- A: `package.el` with MELPA (`lisp/init-elpa.el:18`). Helpers `require-package` and `maybe-require-package` (`init-elpa.el:34-63`). `use-package :ensure t` in the local layer (`init-local.el:81`). Built-in upgrade allowed (`init-elpa.el:24`). One Git package manager on top (`async-installer`).
- B: `package.el` with only China mirrors, Tsinghua (`early-init.el:152-154`). `use-package-always-ensure t`, `always-defer t` (`early-init.el:156-161`). So any `use-package` without `:ensure nil` installs. Signature check is off (`early-init.el:151`). `package-quickstart` is on (`early-init.el:147`).
- Both use Emacs 31 (B: README says 31+, `README.org:15,65`; A: elpa dir naming `elpa-%s.%s`).

### Overlap (both configure it)

magit, multiple-cursors, symbol-overlay, rg, wgrep, corfu, nerd-icons, material-icons, yasnippet, org-modern, ghostel, eglot (built-in), flymake, project/vc/ediff (built-in, different depth), rainbow-delimiters, yaml/json/markdown ts-modes (A via `init-treesitter.el`, B via `init-lang.el:562-600`).

Sources: A `lisp/init-git.el:16`, `init-editing-utils.el` (multiple-cursors), `init-local.el:173`, `init-local-org.el:248`, `init-local-shell.el:164,289`. B `init-vc.el:75`, `init-editor.el:473,481,329,387`, `init-utils.el:67-72`, `init-display.el:2,12,235,835`, `init-terminal.el:111`.

### Only in A

- Completion UI: vertico, vertico-posframe, orderless, marginalia, embark, embark-consult, consult, consult-dir, consult-eglot (`init-minibuffer.el`, `init-local.el:257`).
- Editing: Hel, hel-leader, undo-fu, undo-fu-session, avy, which-key, whole-line-or-region, move-dup, puni, paredit, ws-butler, golden-ratio, pulsar, substitute, ztree, zoxide, vim-tab-bar.
- Project: projectile (`init-projectile.el`), diff-hl (`init-vc.el:28`), git-timemachine, git-link, forge, majutsu.
- Notes and AI: org-gtd, denote, vulpea, org-pomodoro, org-cliplink, claude-code-ide, anvil (MCP), proofread, gt (translate), llm.
- Theme: modus-themes, doom-modeline, spacious-padding, color-theme-sanityinc-*.
- Other: gcmh, compile-angel, exec-path-from-shell, envrc (direnv), eat, many language modes (some in commented-out modules).

### Only in B

- apheleia (format), citre (ctags), dape (debug), emmet-mode, web-mode, powershell, indent-bars, olivetti, colorful-mode, color-picker, calfw, calfw-org, telega, magit-fast, simpcc-mode, nerd-icons-corfu.
- Built-in features B uses deeply: icomplete (fido), completion-preview, viper (off by default), gnus, rcirc, erc, newsticker, eww, proced, speedbar, hideshow, outline.

Sources: B `init-editor.el:180,217,536`, `init-debug.el:2`, `init-lang.el:418,466,557`, `init-display.el:221,235,246`, `init-utils.el:89,101`, `init-www.el:162,287,311,377`.

Caveat: A's package count is large because it lists packages for modules that `init.el` has commented out. B's list comes from `use-package` forms that install by default. I did not run either config to get live package lists.

## 3. Completion and UI stack

| Layer | A | B |
|---|---|---|
| Minibuffer | vertico + orderless + marginalia + embark + consult (`init-minibuffer.el`, `init-corfu.el:9-12`). Orderless is set only after vertico loads | Built-in `fido-mode` and `fido-vertical-mode` (`init-editor.el:352-368`). `completion-styles` are `partial-completion flex initials` (`init-builtin.el:317`) |
| In-buffer | corfu auto, popupinfo, corfu-terminal fallback (`init-corfu.el:17-33`) | corfu with auto delay 0, prefix 2, popupinfo, nerd-icons-corfu (`init-editor.el:387-471`, `init-display.el:25`). Also `completion-preview` for text modes (`init-editor.el:370-385`) |
| Snippets | yasnippet + snippets (`init-local.el:173-182`) | yasnippet with a capf bridge (`init-editor.el:329-350`) and a `snippets/` dir |
| Posframe/child UI | vertico-posframe (`init-local.el:257`) | Child-frame check helper (`nn.el:110-115`) |
| Theme and modeline | modus-themes, doom-modeline (`init-local-themes.el:6,71`) | Own theme `elegant-world`, own modeline `nn-mode-line` (`init.el:94-97`, `init-display.el:302`) |
| Icons | nerd-icons, nerd-icons-completion, nerd-icons-dired (`init-local-themes.el:95-106`) | material-icons for dired and ibuffer (`init-display.el:2-10`), nerd-icons for corfu and modeline |
| Dashboard | none found | Own `*HOME*` page (`init-home.el`) |

B's `completion-preview` styles name `orderless` (`init-editor.el:385`), but I found no orderless package in B. Not confirmed that it resolves.

## 4. Editing model

- A: Hel (Helix-style modal) is the default. Loaded by `init-local-hel.el`; the tag pins are in `package-list.el:34-43`. Initial states: dired normal, magit emacs (`init-local-hel.el:252-253`). A leader layer (hel-leader) uses SPC and maps to `C-c` keys (`init-local-hel.el:39-80`). Evil is commented out (`init-local.el:48-77`). undo-fu replaces `C-r` (`init-local.el:80-86`). The Hel setup does a self-install step (`init-local-hel.el:288-316`).
- B: No modal package. Keys follow a CUA-like style on top of Emacs: `C-z` undo, `C-v` yank, `M-w`/`C-w` act on the line when no region (`init-keybind.el:55,72-74,96-106`). An optional Viper layer exists, off by default via `nn-vim-mode` (`nn.el:30`, `init-editor.el:536-538`). multiple-cursors loads at first input (`init-editor.el:493`).
- Both: multiple-cursors, symbol-overlay (B binds `M-n`, `M-p`: `init-editor.el:473-479`).

## 5. LSP and eglot

- Both use built-in eglot. Neither hooks `eglot-ensure` in the files I searched (rg for `eglot` in `lisp/` and `user-lisp/`). Eglot starts by hand in both. Not confirmed there is no other start path.
- A: `init-eglot.el:7-8` only installs eglot and consult-eglot. Server entries are in language files: Python (`init-python.el:25-37`), Nix (`init-nix.el:11-14`), OCaml (`init-ocaml.el:29-30`).
- B: Detailed tuning in `init-editor.el:287-327`:
  - `eglot-autoshutdown`, events buffer size 0, ignore inlay hints, document highlight and folding range (`:296-304`).
  - JSON-RPC logging off (`:305`, `:327`).
  - A flymake restart after save, using `publishDiagnostics` (`:164-171`).
  - Keys: `<f2>` rename, `<f12>` find definition, `C-.` quick fix (`:289-295`).
  - A clangd launch command with `--query-driver` and the project root (`init-lang.el:31-48`).
  - Right-click menu LSP entries (`init-keybind.el:373-404`).
- B adds citre/ctags as a no-LSP path (`init-editor.el:217-285`), with a fallback to external tags files (`:243-249`).
- Formatting: B uses apheleia on `<f1>` (`init-editor.el:180-198`). A uses per-language formatters in language files (for example `shfmt` at `init.el:243`).
- Debug: B has dape (`init-debug.el:2`). A has no debugger package found.

## 6. Org

- A: two layers.
  - `init-org.el`: Purcell defaults (todo keywords at `:163`, refile at `:127-158`, clock at `:199-210`, pomodoro at `:256`).
  - `init-local-org.el`: `org-directory` is `~/org/` (`:5`). `org-agenda-files` is computed from all `.org` files (`:8-17`). org-modern with todo styling off (`:248-262`).
  - `init-local-gtd.el`: org-gtd pinned to 4.6.1 (`:29`), with a guard if org-gtd is missing (`:40-57`).
  - Notes: denote (`init-local-denote.el:12-16`) and vulpea (`init-local-vulpea.el:22`).
  - Extra: a case guard that stops silent upcasing of Org files (`init-local-case-guard.el`, `init-local.el:461-474`).
- B: One `org` block in `init-lang.el:624-745` with a 7-keyword TODO list (`init-lang.el:695-699`), agenda with one file `~/agenda.org`, capture templates for idea, todo, note, journal, book (`init-lang.el:779-795`), clock, crypt, org-modern (`:835-845`). No GTD package. Calendar views via calfw (`init-utils.el:89-110`).

## 7. Git and project tools

| Topic | A | B |
|---|---|---|
| VCS front end | `C-x g` opens `vc-dir-root`; magit for hard cases (`init-vc.el:15`) | magit with heavy trimming (`init-vc.el:75-123`), own `magit-fast` fork (`:125-133`) |
| Gutter | diff-hl (`init-vc.el:28-35`) | none found |
| Extra git | git-timemachine, git-link, git-modes, magit-todos (`init-git.el:10-44`); forge, jj via majutsu | vc-dir tweaks, ediff window restore, auto smerge (`init-vc.el:13-70`) |
| Project | projectile with `rg --files` (`init-projectile.el:5-12`) | built-in `project.el` plus ripgrep search, extra root markers, ignores (`init-builtin.el:11-23`) |
| Search | consult-ripgrep on `M-?` (`init-minibuffer.el:38-39`) | `rg.el`, wgrep, xref with ripgrep (`init-utils.el:67-87`, `init-editor.el:207-215`) |
| Terminal | ghostel on Mac/Linux, eat, eshell extras (`init-local-shell.el`) | ghostel, project-aware, `C-\`` toggle (`init-terminal.el:111-133`) |

## 8. Performance and startup

| Technique | A | B |
|---|---|---|
| GC at start | `gc-cons-threshold` max in `early-init.el:296-297` | max in `early-init.el:84-85`, never lowered (no gcmh found); forced `garbage-collect` every 5 idle seconds (`early-init.el:9`) |
| GC after start | 128 MB at `emacs-startup-hook` (`init.el:101-104`) and gcmh (`init.el:129-133`) | Not applicable (see above) |
| Compile | compile-angel on load (`init.el:16-81`), `package-native-compile t` (`init-elpa.el:69`) | `native-comp-jit-compilation nil` (`early-init.el:25-26`); no compile-angel found |
| Lazy loading | Mostly eager `require`; use-package in the local layer | `always-defer t`; own hooks `nn-first-input` and `nn-first-file` (`nn.el:60-108,121-122`) |
| File handlers | not set | `file-name-handler-alist` nil during load (`early-init.el:51-60`, `init.el:15`) |
| Process I/O | `read-process-output-max` 4 MB (`init.el:109`) | same value (`early-init.el:30`) |
| Redisplay | `jit-lock-defer-time 0` (`init.el:135`) | same, plus stealth settings (`init-builtin.el:2-9`); `inhibit-redisplay` during startup (`early-init.el:16,42`) |
| Other | frame-size cache (`early-init.el:328-331`); `init-benchmarking.el` require-times table | `load-path-filter-cache-directory-files` (`early-init.el:32`); bidi off (`:35-36`); `executable-find` cache (`:70-76`) |
| TUI | separate light path via `sanityinc/tui-session-p` (`init.el:15,122`) | `_TUI` constant exists (`nn.el:4`); no separate path found |

## 9. Keybinding philosophy

- A: Modal-first. Hel normal state plus a SPC leader that maps to `C-c` sequences. Emacs keys stay for the rest. Dangerous keys are removed (`C-x C-u` unbound: `init-local.el:467`; Hel case keys unbound: `init-local-hel.el:229-230`). `init-local-keybinding.el` is not loaded (`init-local.el:476-477`).
- B: Direct, non-modal, many function keys: `<f1>` format, `<f2>` rename, `<f5>` debug, `<f8>` diagnostics, `<f12>` jump (`README.org:53-60`). It overrides several core keys (`C-v`, `C-z`, `M-w`, `C-w`, `C-a`: `init-keybind.el:55,71-74`) and adds `C-c o` split commands, `C-c w` surround (`:42-52`). A right-click context menu exposes commands (`:327-421`).
- Conflicts in B: `<f12>` is bound for both citre and eglot/xref (`init-editor.el:219`, `:291`). Later load wins. Not tested.

## 10. OS handling

- A: `*is-a-mac*` (`init.el:96`) and `IS-MAC/IS-LINUX/IS-WINDOWS` (`init-local.el:150-152`). OS files: `init-local-macos.el`, `init-local-windows.el`, optional `init-local-linux` (`init-local.el:129-135`). exec-path-from-shell on GUI or daemon, not Windows (`init-exec-path.el:12-15`). Windows PATH patch (`:17-28`).
- A conflict: `init-osx-keys.el:6-7` sets command=meta, option=none. `init-local-macos.el:6-7` sets option=meta, command=super. `init-local-macos` loads later, so it likely wins. Not run to confirm.
- A Windows: `init-local-windows.el:10-47` (w32 attributes, exec-suffixes, `executable-find` cache with invalidation on `exec-path`).
- B: Windows is the main target. `_WIN32` handling in `early-init.el:38-40,62-68,130-142` (UTF-8 DOS coding, w32 pipe size, bash as shell, MSYS env). Mac and Linux appear only in open-external code (`nn.el:177-181`, `init-builtin.el:499-500`). No mac modifier keys or PATH import found.

## 11. Ideas worth borrowing from B (ranked)

1. **Run-once startup hooks** `nn-first-input` and `nn-first-file`. They defer modes (electric-pair, savehist, so-long, yasnippet) until first use. File: `nn.el:60-108,121-122`; use at `user-lisp/init-editor.el:10,29,331`. Combine with `use-package-always-defer` (`early-init.el:160`). Best gain for A's eager `require` list.
2. **Eglot tuning**: drop the events buffer, disable jsonrpc logging, ignore heavy capabilities, restart flymake after diagnostics. File: `user-lisp/init-editor.el:287-327,164-171`. A has no tuning today.
3. **`executable-find` cache for all systems** and `load-path-filter-cache-directory-files`. File: `early-init.el:32,70-76`. A caches only on Windows (`lisp/init-local-windows.el:18-35`). Add the exec-path invalidation that A already has.
4. **File-handler off during load**. File: `early-init.el:51-60`. Small, safe win.
5. **apheleia format-on-key** with one prettier formatter template. File: `user-lisp/init-editor.el:180-198`. Replaces per-language formatter packages.
6. **Magit and ediff trimming**: skip heavy status sections, restore windows after ediff. File: `user-lisp/init-vc.el:37-61,75-123`.
7. **Transient autoload deferral** to speed menu build. File: `user-lisp/init-keybind.el:9-35`.
8. **Built-in project.el setup** (root markers, ignores, ripgrep search) as a lighter option than projectile. File: `user-lisp/init-builtin.el:11-23`.
9. **Font fallback loops by Unicode block** that skip missing fonts. File: `init.el:28-85`. A uses fixed font constants (`lisp/init-local.el:156-180`).
10. **citre/ctags** as an LSP-free jump path. File: `user-lisp/init-editor.el:217-285`. Only if A needs it for C or odd languages.

Not worth borrowing: B's permanent max GC threshold (`early-init.el:84-85`) and `native-comp-jit-compilation nil` (`:25`). A's gcmh and compile-angel setup is safer. Also skip B's lexical-binding default of nil (`early-init.el:8`).
