# Hel cheatsheet

Hel normal-state editing follows the upstream
[keybindings reference](https://github.com/anuvyklack/hel/blob/main/docs/keybindings.org).

Personal bindings live in `lisp/init-local-hel.el`. Press `SPC` in Hel Normal or
Emacs state for the existing leader map; which-key shows available continuations. Dired starts in Hel Normal state, so `SPC` and `hjkl` work there. Hel requires Emacs 29.1 or newer; older Emacs versions start without it.

## Frequent leader keys

| Key | Command |
| --- | --- |
| `SPC SPC` | Save buffer |
| `SPC :` | Run command |
| `SPC .` / `SPC f` | Find file |
| `SPC ,` | Switch buffer |
| `SPC r` | Recent file |
| `SPC b` | Buffer commands |
| `SPC c` | Claude, comment, and clock commands |
| `SPC d` | Editing, Denote, and Dired commands |
| `SPC e` | Eval, Eshell, and Ediff commands |
| `SPC g` | Git, translation, and Ghostel commands |
| `SPC j` | Journal commands |
| `SPC o` | Org commands |
| `SPC s` | Search and org-supertag commands |
| `SPC w` | Window commands |
