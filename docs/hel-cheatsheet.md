# Hel cheatsheet

Hel normal-state editing follows the upstream
[keybindings reference](https://github.com/anuvyklack/hel/blob/main/docs/keybindings.org).
[hel-leader](https://github.com/anuvyklack/hel-leader) translates modifier-free
key sequences into native Emacs bindings.

Personal bindings live in `lisp/init-local-hel.el`. Press `SPC` in Hel Normal or
Emacs state; which-key shows available continuations. Dired starts in Hel Normal
state and keeps `hjkl` movement after switching to Emacs state. Magit starts in
Hel Emacs state, preserving Magit commands except for `hjkl` movement. Hel requires
Emacs 29.1 or newer; older Emacs versions start without it.

## Frequent leader keys

| Key | Command |
| --- | --- |
| `ZZ` / `SPC b s` | Save buffer |
| `SPC :` | Run command |
| `SPC .` / `SPC f` | Find file |
| `SPC ,` | Switch buffer |
| `SPC r` | Recent file |
| `SPC b` | Buffer commands |
| `SPC a` | Claude, comment, and clock commands |
| `SPC d` | Editing, Denote, and Dired commands |
| `SPC e` | Eval, Eshell, and Ediff commands |
| `SPC g` | Git, translation, and Ghostel commands |
| `SPC j` | Journal commands |
| `SPC o` | Org commands |
| `SPC s` | Search commands |
| `SPC s b` | Open the scratch buffer |
| `SPC v` | Vulpea commands (`t` opens the Task Table) |
| `SPC w` | Window commands |

## Clock keys

| Key | Command |
| --- | --- |
| `SPC c t` | Update clock time |
| `SPC c i` | Clock in |
| `SPC c o` | Clock out |
| `SPC c p i` | Punch in using the Organization task in `todo.org` |
| `SPC c p o` | Punch out |
| `SPC c g` | Go to the active clock |
| `SPC c l t` | Clock into the last interrupted task |
| `SPC c s` | Switch task |

The same clock commands remain available under `SPC a`.

## Normal-state editing

| Key | Action |
| --- | --- |
| `d` | Delete the selection without changing the kill ring; without a selection, delete forward |
| `D` | Cut the selection into the kill ring; without a selection, delete backward without changing the kill ring |
| `v` | Toggle selection extension |
| `x` | Expand or contract the selection linewise downward |
| `X` | Expand or contract the selection linewise upward |
| `y` | Copy the selection into the kill ring |
| `p` | Paste before the selection; linewise content goes above the current line |
| `P` | Paste after the selection; linewise content goes below the current line |

Use `v` plus motions for a characterwise selection, or `x` for a linewise
selection. Press `D` to cut the selection or `y` to copy it.

## Scrolling and paste

| Key | Action |
| --- | --- |
| `C-v` | Paste from the kill ring |
| `C-d` / `C-u` | Scroll down / up by half a page |
| `C-f` / `C-b` | Scroll down / up by a full page |

## Native modifier keys

| Input | Native prefix |
| --- | --- |
| `SPC <key>` | `C-c <key>` |
| `SPC SPC` | `C-c C-c` |
| `SPC c` | `C-c C-` |
| `SPC x` | `C-x` |
| `SPC m` | `M-` |
| `SPC G` | `C-M-` |
| `Backspace` | Undo the last leader key |
