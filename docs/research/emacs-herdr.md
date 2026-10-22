# emacs-herdr: Herdr agent multiplexer in Emacs

Verified: 2026-10-21

Sources: emacs-herdr at commit `e2ea729` (2026-10-12), herdrdev/herdr
README at `main`, the local `herdr 0.9.5` binary (`--help` output only), and
this repository. Line numbers for `herdr.el` and `README.org` refer to commit
`e2ea729`.

## Result

Install emacs-herdr with `use-package :vc`, as `lisp/init-git.el:71-73`
does for magit-fast. Keep it deferred and bind one key to `herdr-menu`. Do not
enable `herdr-mode` at startup until you decide that the poll and the
notifications are worth one `herdr` process every 2 seconds. The Herdr binary
is already installed on this Mac (version 0.9.5
from Homebrew), and the Ghostel package that emacs-herdr needs is already
configured in `lisp/init-local-shell.el:297-326`.

## What it is

- **Herdr** is "a tmux-like terminal multiplexer for AI coding agents"
  ([emacs-herdr README.org:3](https://github.com/baongoc124/emacs-herdr/blob/main/README.org)).
  Its own README calls it "the runtime your coding agents live on". It keeps
  terminals in a background server, marks each pane as working, blocked, or
  idle, and uses a tmux-style `ctrl+b` prefix. It is one Rust binary, licensed
  Apache-2.0
  ([herdrdev/herdr README.md](https://github.com/herdrdev/herdr/blob/main/README.md)).
  Latest release: v0.9.5, 2026-10-14
  ([releases](https://github.com/herdrdev/herdr/releases/tag/v0.9.5)).
- **emacs-herdr** (`herdr.el`, one file, version 0.1.0) runs the full Herdr
  TUI in a Ghostel buffer and adds Emacs commands: an agent picker sorted by
  attention, "new agent for this project", send region to an agent, one
  Ghostel buffer per agent, a mode-line count of blocked agents, and desktop
  notifications (README.org:9-25). All calls go through the `herdr` CLI, not
  the socket API (README.org:7, herdr.el:41). License GPL-3.0-or-later
  (herdr.el:10, `LICENSE`). Latest commit 2026-10-12; 2 GitHub stars on the
  verification date (`gh repo view`).

## Requirements

| Item | Requirement | Source | Status here |
|------|-------------|--------|-------------|
| Emacs | 29.1+ | herdr.el:7 | Emacs 31 (`elpa-31.1/`) |
| ghostel | any (header says `0.1`) | herdr.el:7 | MELPA `ghostel-20261012.1316`; `ghostel-exec` takes the 4th IDENTITY arg that herdr.el:415 passes (`ghostel.el:5558`) |
| transient | 0.4 | herdr.el:7 | built in |
| herdr binary | >= 0.8.2 (needs `api snapshot`, `agent prompt`, `agent start --kind`, `terminal_title_stripped`) | README.org:36-40 | 0.9.5; `herdr api snapshot`, `agent prompt`, `agent attach --takeover`, `agent start --kind`, `agent focus`, `pane send-text` all exist (`--help`) |
| terminal-notifier | optional, macOS click-to-show notifications | README.org:153-159, herdr.el:831-839 | not installed; `osascript` fallback is used (herdr.el:840-847) |

Install Herdr on macOS: `brew install herdr`, or
`curl -fsSL https://herdr.dev/install.sh | sh`, or `mise use -g herdr`
([herdr README.md, "install"](https://github.com/herdrdev/herdr/blob/main/README.md)).
Herdr's README does not state a minimum macOS version (unverified).

## Install options for this config

| Option | Repo precedent | Notes |
|--------|----------------|-------|
| `use-package` `:vc` | `lisp/init-git.el:71-73` (magit-fast), `lisp/init-local-majutsu.el:97-99`, `lisp/init-local-macos.el:32-34` | **Recommended.** package.el installs `ghostel` from MELPA for the Package-Requires; `ml-update-all-packages` already runs `package-vc-upgrade-all` (`lisp/init-local.el:441`). |
| async-installer `:tag` pin | `lisp/package-list.el:11-13` (anvil), Hel | Use only if you want a pinned commit. The repo has no tags, so you would pin `:commit`. |
| Vendor into `site-lisp/` | `site-lisp/` | Not recommended: no update path, and the package changes often (3 commits on 2026-10-12). |
| MELPA `maybe-require-package` | many | Not possible: emacs-herdr is not on MELPA (its README gives only `:vc` or a checkout, README.org:43-61). Unverified against the MELPA recipe list. |

## Commands and options

Autoloaded commands (herdr.el `;;;###autoload` markers): `herdr` (pop to
`*herdr*`, start the TUI if needed), `herdr-hide`, `herdr-toggle`,
`herdr-menu` (transient), `herdr-switch-agent`, `herdr-attach-agent`,
`herdr-last-agent`, `herdr-agents` (tabulated list), `herdr-new-agent`,
`herdr-goto-blocked`, `herdr-send-region` (`C-u` submits),
`herdr-submit-region`, and the global minor mode `herdr-mode` (poll timer,
mode-line `● N`) (README.org:63-79, herdr.el:418-1157).

Menu keys inside `herdr-menu`: `o` open, `q` hide, `s` switch, `a` attach,
`SPC` last agent, `n` new agent, `b` blocked, `r` / `R` send region, `m`
toggle `herdr-mode`; the menu key again runs `herdr-menu-repeat-command`
(README.org:81-99, herdr.el:1104-1128).

User options (herdr.el:59-164, README.org:128-145): `herdr-executable`
(`"herdr"`), `herdr-poll-interval` (2), `herdr-default-agent-kind`
(`"claude"`), `herdr-menu-key` (nil), `herdr-agent-display` (`tui` or
`buffer`), `herdr-attach-takeover` (t), `herdr-mark-seen` (t),
`herdr-notify-statuses`, `herdr-status-change-functions`,
`herdr-attach-header-line`, `herdr-header-label-width`,
`herdr-menu-repeat-command`, `herdr-sync-workspace-labels` (nil),
`herdr-sync-tab-labels` (nil), `herdr-workspace-label-function`.

Keymap: `herdr-agents-mode-map` only (herdr.el:938). The package binds no
global key unless you set `herdr-menu-key`; its `:set` function calls
`keymap-global-set` and adds the key to `ghostel-keymap-exceptions`
(herdr.el:131-143, 153-164).

## Module: `lisp/init-local-herdr.el`

The module is now in the repository. It installs herdr with `use-package :vc`
only when the `herdr` binary exists, and it adds these keys:

| Key | Command | Result |
|-----|---------|--------|
| `C-c m` | `ml/herdr-send-raw` | Type the region or line into an agent, with no code fence; `C-u` also presses Enter (`herdr pane run`). When the focused pane is not an agent and its tab has one agent, sends there without a prompt, else asks; then focuses the agent |
| `C-c M` | `herdr-menu` | Herdr transient menu |
| `C-c W` | `ml/herdr-copy-pane-text` | Copy the region or line without the sidebar, borders, or scrollbar |
| `RET` in Ghostel copy mode | advice on `ghostel-readonly-copy` | In `*herdr*`, copy only the pane text |

For a whole line (no region), `C-c m` and `C-c W` also remove a leading
Claude Code `❯` or `⏺` marker, so `❯ ! cmd` is sent as `! cmd`. Tests:
`tests/init-local-herdr-tests.el`.

Reasons for each choice:

- `executable-find` gate: without the binary every command fails in
  `call-process` (herdr.el:197-205). `exec-path` already has Homebrew paths
  from `exec-path-from-shell` (`lisp/init-exec-path.el:5-15`).
- `:bind` instead of `herdr-menu-key`: `herdr-menu-key` binds the key only
  when `herdr.el` loads (its `:set`, herdr.el:153-162), so with a deferred
  package the key would not exist until another herdr command ran. `:bind`
  makes an autoload. `C-c` is already in the default
  `ghostel-keymap-exceptions` (`ghostel.el:609-610`), so `C-c m` and `C-c M`
  also reach Emacs from inside `*herdr*` in semi-char mode. No other binding
  for them exists in `lisp/` (`rg 'C-c [mM]' lisp/`).
- No `herdr-mode` hook: README.org:47 uses `:hook (after-init . herdr-mode)`,
  but that loads `ghostel` at startup (herdr.el:46) and starts a 2-second poll
  that spawns `herdr api snapshot` each time (herdr.el:897-928). Add it only if
  you want the blocked count and notifications.

Where to require it: in `lisp/init-local.el`, directly after
`(require 'init-local-shell)`. `herdr.el` does `(require 'ghostel)`
(herdr.el:46), and the Ghostel setup that selects the patched native module
runs from `init-local-shell` (`lisp/init-local-shell.el:297-305`). With this
order, Ghostel is configured before herdr can load it, also if you later turn
on `herdr-mode` at startup. The `init-local-*` name matches AGENTS.md ("Keep
personal overrides in `lisp/init-local.el`").

## Verify pane-text changes

`herdr pane read <PANE_ID> --source visible` returns a pane's screen rows
without the sidebar, borders, or scrollbar. Use it as ground truth for any
change to `ml/herdr--pane-text`: in the live `*herdr*` buffer, run the helper
over every row of each pane (`herdr pane layout` lists the pane ids) and
compare row by row. One hand-picked line is not enough, because wide
characters shift borders by a column on some rows only. Expected differences:
the pane's top and bottom frame lines, and a partial first row when the
selection starts inside a line.

## Conflicts and risks

- **You already run Herdr in Ghostel by hand.** `docs/ghostel-module.md:9`
  names a Herdr border bug as the reason for the patched Ghostel module. The
  `*herdr*` buffer uses `ghostel-mode` (herdr.el:410), so the same patched
  module, `ml/ghostel-sync-hel`, and the `M-1`..`M-9` exceptions
  (`lisp/init-local-shell.el:160-168`) apply to it.
- **`ctrl+b` prefix.** `C-b` is not in `ghostel-keymap-exceptions`, so it
  goes to Herdr in semi-char mode. In char mode all keys go to the terminal;
  press `M-RET` first to reach Emacs keys (README.org:57-60).
- **Herdr width bug.** Changing the `*herdr*` pane width corrupts agent
  output; the package sets `split-width-threshold` to nil in its buffers
  (README.org:283-301, herdr.el:413, 537). Commands from this config that split
  windows side by side next to `*herdr*` can still trigger it (unverified).
- **Server names.** `herdr-sync-workspace-labels` and `herdr-sync-tab-labels`
  rewrite names on the Herdr server and do not keep the old names
  (README.org:186-196). Keep them nil.
- **Server start.** When the server is down, commands offer to start it with
  `nohup herdr server &` through a shell; it outlives Emacs (herdr.el:273-287).
- **Direct attach takeover.** `herdr-attach-takeover` is t, so attaching from
  Emacs replaces a `herdr agent attach` client in another terminal
  (README.org:222-229).
- **macOS notifications.** Without terminal-notifier, `osascript`
  notifications do nothing on click (herdr.el:840-847). With it, the click
  activates bundle `org.gnu.Emacs` (herdr.el:835); all three local Emacs.app
  builds use that ID (`CFBundleIdentifier`). Click-to-show uses `emacsclient`
  (herdr.el:879-884); `init.el` starts the server.
- **No overlap with vterm, eat, or tmux**: `init-terminals` (eat) is disabled
  (`init.el:170`), and `lisp/` has no vterm or tmux setup. `C-c a` holds
  Claude Code IDE keys (`lisp/init-local-hel.el:357-359`); Herdr is a separate
  runner, and both can coexist.
- **Young package.** Version 0.1.0, 2 stars, rapid commits. An unpinned `:vc`
  install follows the default branch.

## Open questions

- Hel leader: answered. `SPC <key>` runs the global `C-c <key>` binding
  (`external-packages/hel-leader/hel-leader.el:198-202`), but
  `hel-leader-meta-prefix` is `"m"`, so `SPC m` starts an `M-` key. `SPC M`
  and `SPC W` work only in Ghostel Emacs mode (`M-e`); `C-c` keys are simpler.
- Does the transient repeat key work with a two-key sequence such as
  `C-c M`? `herdr--menu-repeat-key` uses the invoking keys
  (herdr.el:1074-1080, 1130-1140). Unverified; README examples use `C-9`.
- Do you want `herdr-mode` (poll, mode-line, notifications) on at startup?
- Default agent kind: keep `"claude"`, or use another kind from
  `herdr--agent-kinds` (herdr.el:189-193)?
- Does Herdr 0.9.5 still emit `terminal_title_stripped` in
  `herdr api snapshot`? The command exists; the field was not checked because
  no server was started.
- Install `terminal-notifier` (`brew install terminal-notifier`) for
  click-to-show notifications?
