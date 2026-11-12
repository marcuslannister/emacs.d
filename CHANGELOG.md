# Changelog

Notable changes to this fork of `zHaOdANiuu/.emacs.d`, newest first inside each group. It loosely follows [Keep a Changelog](https://keepachangelog.com/). The fork has no releases yet, so all changes are under "Unreleased". Changes of the Upstream before the fork are not listed.

## Unreleased

### Added
- In Dired, `/` jumps to a file (`dired-goto-file`) and `K` kills lines (`dired-do-kill-lines`), in both Hel states. `/` replaces the buffer search there.
- `SPC z t` (`C-c z t`) runs `zoxide-travel`: pick a ranked directory in the fido list and open it. The key and the package exist only when the `zoxide` program is on `PATH`; without it, startup shows a warning and goes on.
- The `org-case-check` skill (ported from the Earlier configuration) and the `elisp-reviewer` agent, which checks Emacs Lisp changes against the rules of this fork.
- `scripts/windows-setup.ps1` skips MSYS2 and the MINGW64 toolchain when the Emacs on `PATH` has `libgccjit-0.dll` beside `emacs.exe`, as a prebuilt build such as kiennq's does.
- `scripts/windows-setup.ps1` makes `anvil-stdio.cmd` in `~\.local\bin` and puts that folder on the user `PATH`, so MCP clients can start the Anvil bridge on Windows.
- Anvil runs on Windows too and starts by itself on macOS and Windows. Its `worker` module is on and its `org` module stays off. The bridge script `anvil-stdio.sh` lives in the config root.
- `scripts/windows-setup.ps1` checks for Aporetic Sans Mono and MonoLisa and can install fonts from a folder (`-FontDir`).
- `scripts/windows-setup.ps1` and a "New Windows PC" section in `docs/windows-setup.md` set up a new Windows PC: Scoop, programs, the MINGW64 toolchain, the fork, `auto-save`, and fonts.
- A Vim-style tab bar with `M-1` to `M-9` for tabs.
- Herdr (the agent multiplexer) on Windows as well as macOS.
- A saved undo history (`undo-fu-session`), with `C-r` as the built-in redo.
- `auto-save` loads from its checkout (`~/github/auto-save`) and is skipped with a warning when the checkout is missing.
- Herdr, the agent multiplexer, as a pinned Git package.
- Ghostel with Hel, a vi copy mode, fixes for upstream bugs, and a shell for Windows.
- `marginalia` and `nerd-icons-completion` on top of fido, for file details and icons.
- The Modus Operandi Tinted theme, and MonoLisa and Maple Mono in the font lists.
- Vulpea, the note database.
- Denote and the Denote journal.
- `org-gtd` for capture, clarify, organize, and engage.
- An append-and-review note in Org.
- Org clocking, reminders, and agenda order from the Norang guide.
- Org moves to the Local layer, with `org-directory` set to `~/org`.
- Hel and `hel-leader`, with one leader table (`my/hel-leader-bindings`) and the Hel state in the mode line.
- Anvil (AI tools that run inside Emacs), at first off by default.
- The pinned Git packages install through `async-installer`.
- JIT native compilation is on, with a helper that finds the MINGW64 `libgccjit` on Windows or turns native compilation off with a warning (ADR 0001).
- The case guard, the PATH import for macOS, and `ws-butler`; `init.el` loads the Local layer with one `(require 'init-local)` line.
- `./test-startup.sh` loads the config in batch Emacs and runs the checks in `tests/startup/checks.el`. CI runs it on macOS (GUI build) and Windows, and a second time on the installed state.

### Changed
- Symbols and punctuation use the default monospace font when it has the glyph (`use-default-font-for-symbols` is `t`; the Base set `nil`), so Ghostel and Herdr keep 1-column symbols instead of falling back to Apple Symbols or Segoe UI Symbol. A glyph that the default font lacks, such as `⎿`, still falls back.
- The Emacs server has the default name `server`, so plain `emacsclient` reaches it.
- Aporetic Sans Mono is the first font on Windows, and MonoLisa is the first font on macOS.
- Tabs use the built-in tab keys.
- `TAB` in fido inserts the selected candidate.
- `F5` runs `dape` again.
- The Base lets async native compilation run.
- Package archives are the official ones; the signature check is off on Windows only.
- The post-startup checks moved into `tests/startup/checks.el`.
- The fork is set up: the personal identity is out of the Base, and a startup test, CI, and docs are added.

### Fixed
- In Dired, `h`, `j`, `k`, and `l` move in Hel Emacs state, where `Esc` goes. Dired's own `j` opened "Goto file:" and did not move down.
- Organizing a Project in `org-gtd` no longer fails with "State `NEXT' not valid in this file": `org-todo-keywords` is `TODO NEXT WAIT | DONE CNCL`, and a startup check covers it.
- The cutover review: `scripts/windows-setup.ps1` identifies the fork by `user-lisp\init-local.el` and not only by its URL, the docs say to run only one Emacs, and they warn that an Emacs run as administrator gets no worker daemons.
- The minibuffer frame fits a multi-line prompt, caps its height, and uses the editor background.
- Box and block characters draw with MonoLisa.
- The fringe has the text background.
- `project` loads before Ghostel can load.
- Dired picks the `ls` program again after the PATH import, and drops the GNU-only option when the program rejects it.
- A failure to load Hel no longer stops the Local layer.
- `async-installer` is not upgraded with the other VC packages.
- The load-path filter is set only when its callees are loaded.
- Several test fixes: file names compare with `file-equal-p` and `expand-file-name`, and the startup check lists Dired with plain switches.

### Removed
- The `telega` Telegram client.
- The `simple-mpv` music player.
