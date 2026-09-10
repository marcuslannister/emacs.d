# Ghostel cheatsheet

Ghostel is the built-in terminal emulator package (`M-x ghostel`, `SPC g h` /
`C-c g h`). Personal bindings and input-mode wiring live in
`lisp/init-local-shell.el`.

## Starting a terminal

| Key | Command |
| --- | --- |
| `SPC g h` / `C-c g h` | Start a Ghostel terminal buffer |
| `SPC g o` / `C-c g o` | Start a Ghostel terminal for the current project |
| `M-t` | Split right and open a fresh, auto-numbered Ghostel terminal there |

## Input modes

Ghostel has four input modes. Hel and `ml/ghostel-copy-vi-mode` are kept in
sync with whichever mode is active (see `ml/ghostel-sync-hel`).

| Key | Switches to | Notes |
| --- | --- | --- |
| `M-e` | Emacs mode | Buffer is read-only; ordinary Emacs/Hel keys work |
| `M-v` | Copy mode | Freezes the display; `ml/ghostel-copy-vi-mode` takes over |
| (default) | Semi-char mode | Most keys go straight to the shell |

## Copy mode (tmux-style vi selection)

Active only while `ml/ghostel-copy-vi-mode` is on (i.e. in copy mode).

| Key | Action |
| --- | --- |
| `h` / `j` / `k` / `l` | Move by character / line |
| `w` / `b` | Move by word |
| `0` / `$` | Beginning / end of line |
| `g` / `G` | Beginning / end of buffer |
| `SPC` | Start selecting; keep moving to extend |
| `RET` | Copy the selection and exit copy mode |
| `q` / `C-g` | Exit copy mode without copying |

## Keys that always reach Emacs

Semi-char mode forwards most keys to the shell, but these pass through to
Emacs regardless of mode (`ghostel-keymap-exceptions`, plus `M-1`..`M-9` added
locally for tab-bar tab selection):

| Key | Passes through as |
| --- | --- |
| `C-c`, `C-x`, `C-u`, `C-h`, `M-x`, `M-:`, `C-\` | Native Emacs prefix/command |
| `M-1` .. `M-9` | `tab-bar-select-tab` (global tab switch) |

So `C-c w w` (other-window) and `C-x o` both work from inside a Ghostel
buffer without leaving semi-char mode. `SPC` is deliberately **not** an
exception — it's a plain character the shell needs, so making it a leader key
here would break normal typing.

## Ghostel's own `C-c` terminal keys

These come from the Ghostel package itself, active in semi-char/char mode:

| Key | Action |
| --- | --- |
| `C-c C-c` | Interrupt |
| `C-c C-z` | Suspend |
| `C-c C-d` | EOF |
| `C-c C-\` | Quit |
| `C-c C-t` | Enter copy mode |
| `C-c C-y` | Paste |
| `C-c M-l` | Clear scrollback |
| `C-c M-w` | Copy scrollback |
| `C-c C-n` / `C-c C-p` | Next / previous hyperlink |
| `C-c M-n` / `C-c M-p` | Next / previous prompt (OSC 133) |
| `C-q` | Send next key literally |
| `C-y` / `M-y` | Yank / yank-pop |

## Switching between Ghostel buffers

Not bound to a key by default — invoke with `M-x`:

| Command | Scope |
| --- | --- |
| `ghostel-next` / `ghostel-previous` | Cycle all Ghostel buffers |
| `ghostel-project-next` / `ghostel-project-previous` | Cycle within the current project |
| `ghostel-list-buffers` | Pick one from a list |
