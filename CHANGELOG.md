# Changelog

Notable changes to this fork of `zHaOdANiuu/.emacs.d`, newest first inside each group. It loosely follows [Keep a Changelog](https://keepachangelog.com/). The fork has no releases yet, so all changes are under "Unreleased". Changes of the Upstream before the fork are not listed.

## Unreleased

### Added
- `telega`, the Telegram client, on macOS only (`init-local-telega.el`); no other system installs or loads it. It uses the SOCKS5 proxy of the Base (`nn-proxy-port`). It needs TDLib 1.8.66 or newer: nix-config links it to `~/.local/share/tdlib` on the Apple silicon Macs, and the first `M-x telega` offers to build `telega-server` there. The Intel Mac has no TDLib. It uses the Symbola font (installed by nix-config) as the last fallback, as the telega FAQ advises, so symbols that macOS fonts lack no longer show as hex boxes; without the font, the first `M-x telega` shows a warning. The Leisure menu has its entry back on macOS.
- `SPC g t` (`C-c g t`) translates with `gt` and StarDict (`sdcv`), between English and Chinese, as in the Earlier configuration. Without `sdcv`, startup shows a warning and the key is not bound.
- Harper, an offline grammar checker, runs through Eglot in Org, Markdown, and text buffers (`init-local-harper.el`). `SPC e g g` (`C-c e g g`) turns it on or off in the current buffer, and `SPC e g a` (`C-c e g a`) shows the fixes for a mark. No mode hook starts it, because Harper marks Org syntax too. It uses the American dialect and the user dictionary `~/.config/harper-ls/dictionary.txt`. nix-config installs `harper-ls`; without it, Eglot shows a warning when it loads.
- A terminal-only session (`emacs -nw`) loads only the Base, Hel, the Modus theme, and Markdown mode (`init-local-tui.el`). It has no case guard, so it does not protect `~/org` from case damage: do not edit those files there. The Base's `init-lang`, `init-www`, and `init-home` (language modes, EWW, Gnus, ERC, the start screen) do not load there: `init.el` skips them and saves about 115 ms, and the session opens in `*scratch*`. The theme adds about 13 ms and Markdown about 3 ms. `use-package` installs nothing there. The whole start takes about 0.45 s (`emacs -nw -Q`: 0.16 s). It starts no server, no Anvil workers, and no `async-installer`, so it can run next to Emacs.app.
- Built-in Which-Key shows Hel leader menus after 1.5 seconds, matching the Earlier configuration. Menu labels describe this fork's commands, including VC, proofreading, Ghostel, and Org GTD.
- `SPC n b r` (`C-c n b r`) posts the region to Blinko, a note server. `M-x my/blinko-post-buffer` and `M-x my/blinko-post-content` post the buffer or typed text. The server and token come from auth-source (`login apikey`); with several such entries, set `my/blinko-endpoint`. The client is the `blinko.el` of the Earlier configuration, rewritten in the Local layer.
- `SPC g p` (`C-c g p`) proofreads selected text with `llm`; a prefix argument asks for a freer rewrite. The original and suggestion stay together in a merge conflict, with changed words highlighted. Endpoint settings stay in a Git-ignored file, and credentials come from auth-source.
- `README.org` has the one-time steps that build the `markdown` and `markdown-inline` tree-sitter grammars, so `.md` files open in `markdown-ts-mode`. The Base skips its Markdown setup until both grammars exist, so a new machine had no Markdown styling. Windows needs `scoop install gcc` for the build (see `docs/windows-setup.md`), and `scripts/windows-setup.ps1` prints this as a next step.
- In Dired, `/` goes to a file (`my/dired-goto-file-or-folder`) and `K` kills lines (`dired-do-kill-lines`), in both Hel states. `/` replaces the buffer search there. When the listing does not have the folder of the file, `/` opens that folder. A missing file, or a line that `K` or omit mode hides, gives an error.
- `SPC z t` (`C-c z t`) runs `zoxide-travel`: pick a ranked directory in the fido list and open it. The key and the package exist only when the `zoxide` program is on `PATH`; without it, startup shows a warning and goes on.
- The `org-case-check` skill (ported from the Earlier configuration) and the `elisp-reviewer` agent, which checks Emacs Lisp changes against the rules of this fork.
- `scripts/windows-setup.ps1` makes `anvil-stdio.cmd` in `~\.local\bin` and puts that folder on the user `PATH`, so MCP clients can start the Anvil bridge on Windows.
- Anvil runs on Windows too and starts by itself on macOS and Windows. Its `worker` module is on and its `org` module stays off. The bridge script `anvil-stdio.sh` lives in the config root.
- `scripts/windows-setup.ps1` checks for Aporetic Sans Mono and MonoLisa and can install fonts from a folder (`-FontDir`).
- `scripts/windows-setup.ps1` and a "New Windows PC" section in `docs/windows-setup.md` set up a new Windows PC: Scoop, programs, the fork, `auto-save`, and fonts.
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
- JIT native compilation is on, except on Windows. There a helper turns it off and loads no `.eln` file, because Defender scans each `.eln` file as a DLL and makes loading much slower (ADR 0001).
- The case guard, the PATH import for macOS, and `ws-butler`; `init.el` loads the Local layer with one `(require 'init-local)` line.
- `./test-startup.sh` loads the config in batch Emacs and runs the checks in `tests/startup/checks.el`. CI runs it on macOS (GUI build) and Windows, and a second time on the installed state.

### Changed
- `early-init.el` no longer loads `package.el` at start, in any session (about 75 ms). `package.el` loads when a command needs it, and the `package` settings (archives, quickstart, signature check) apply then.
- Proofreading no longer shows the `llm` non-free API license warning.
- Dired starts in Hel Emacs state, so Dired's own `m`, `u`, `d`, `C`, and `R` keys work without `Esc`. `h`, `j`, `k`, and `l` still move, and the leader `SPC` still works.
- Dired sorts files and directories by modification date, newest first (`-Ahlt --time-style=long-iso`), as in the Earlier configuration. A newer file stays above an older directory. `-A` hides `.` and `..`. The GNU-only `--time-style` is dropped when `ls` rejects it, so a stock macOS `ls` still opens Dired.
- Olivetti no longer starts by itself in Gnus article, EWW, Org, or Markdown buffers. Run `M-x olivetti-mode` when you want it.
- Markdown buffers no longer show the fill-column indicator, because a line longer than `fill-column` hid the bar.
- Links open in the system browser, not in EWW (`browse-url-browser-function` is `browse-url-default-browser`). `M-x eww` and `C-c /` still open EWW.
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
- Copying in a terminal-only session (`emacs -nw`) inside Herdr reaches the system clipboard. Herdr does not report OSC 52 support, so Emacs never turned copy on; `init-local-tui.el` now turns it on. Kitty and other terminals that pass the sequence work the same.
- In Dired, `h`, `j`, `k`, and `l` move in Hel Emacs state, the state Dired starts in. Dired's own `j` opened "Goto file:" and did not move down.
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
- The `simple-mpv` music player.
