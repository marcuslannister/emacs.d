# Dired cheatsheet

Dired is Emacs's built-in file manager. Personal bindings live in
`lisp/init-dired.el` (movement, isearch, wdired, diff-hl) and
`lisp/init-local-hel.el` / `lisp/init-local.el` (Hel state, leader keys,
zoxide).

## Opening Dired

| Key | Command |
| --- | --- |
| `C-x C-j` | `dired-jump` — open Dired for the current file's directory |
| `C-x 4 C-j` | `dired-jump-other-window` |
| `SPC d i` / `C-c d i` | `dired` — prompt for a directory |
| `M-x dired-jump-with-zoxide` | Pick a zoxide-remembered directory and open it in Dired |

## Hel state: Normal vs. Emacs

Dired starts in Hel Normal state, like every buffer without a more specific
setting (see `docs/hel-cheatsheet.md`). Normal state's own single-letter
commands take priority over Dired's, so `d`, `m`, `u`, `x`, `v`, `y`, `C`,
`g`, and `%` run Hel's delete/mark/undo/selection commands instead of
Dired's mark, delete, view, copy, revert, or regexp-command prefix.

Press `<escape>` to drop into Hel Emacs state, where Dired's own keymap is
in charge and every native single-letter command works as usual (`m` mark,
`u` unmark, `d` flag for deletion, `x` execute flagged deletions, `C` copy,
`R` rename, `g` revert, `%` regexp commands, `!` shell command, and so on —
see `C-h m` in a Dired buffer for the full list). Press `i` to return to
Normal state for Hel-style navigation. This round-trip is not
Dired-specific: `dired-mode-map`'s parent is `special-mode-map`, and Hel
binds `<escape>` / `i` there for exactly this purpose.

| Key | Effect |
| --- | --- |
| `<escape>` | Normal state → Emacs state (native Dired commands) |
| `i` | Emacs state → Normal state (Hel navigation) |

## Movement and search

`h`/`j`/`k`/`l` move the same way in both states (character/line motion), so
switching states never costs you navigation. `/`, `n`, and `p` differ: Normal
state uses Hel's own incremental search, Emacs state uses Dired's filename
isearch.

| Key | Normal state | Emacs state |
| --- | --- | --- |
| `h` / `j` / `k` / `l` | `hel-backward-char` / `hel-next-line` / `hel-previous-line` / `hel-forward-char` | `backward-char` / `dired-next-line` / `dired-previous-line` / `forward-char` |
| `'` | `dired-up-directory` (unshadowed in either state) | `dired-up-directory` |
| `/` | `hel-search-forward` | `dired-isearch-filenames` |
| `n` | `hel-search-next` | `isearch-repeat-forward` |
| `p` | `hel-paste-before` | `isearch-repeat-backward` |

Other native bindings: `C-c C-q` starts `wdired-change-to-wdired-mode`;
`mouse-2` opens the file under the pointer (`dired-find-file`).

## Editable filenames (wdired)

`C-c C-q` switches the Dired buffer into `wdired-mode`, where filenames are
plain editable text — rename by editing the buffer, then commit or discard:

| Key | Action |
| --- | --- |
| `Z Z` | `wdired-finish-edit` — apply the renames |
| `Z Q` / `C-g` | `wdired-abort-changes` — discard edits |
| `<escape>` | Exit wdired (via Hel's `helheim-wdired-exit`) |

## Leader keys

| Key | Command |
| --- | --- |
| `SPC d i` / `C-c d i` | Open Dired |
| `SPC d c` / `C-c d c` | `ai/cd-to-current-buffer` — shell `cd` to the current buffer's directory |
| `SPC d p` / `C-c d p` | `pwd` |

## Visual indicators

- `diredfl-global-mode` colorizes the listing: permissions, owner/group,
  dates, symlink targets, and executable files each get their own face.
- `diff-hl-dired-mode` marks each file's Git status in the margin, including
  files Git ignores. Its status refresh is wrapped so a Git process still
  running when the temp status buffer is killed does not prompt to confirm
  (`sanityinc/diff-hl-dired-status-files-no-query`); Windows hits this race
  far more often than macOS or Linux.

## Settings

| Variable | Value | Effect |
| --- | --- | --- |
| `dired-listing-switches` | `"-Ahlt --time-style=long-iso"` | All entries but `.`/`..`, long format, human-readable sizes, newest-first, ISO-8601 timestamps |
| `dired-dwim-target` | `t` | Copy/rename defaults to the other visible Dired window's directory |
| `dired-recursive-deletes` | `'top` | Deleting a non-empty directory asks once, not once per file |

## Zoxide integration

| Key | Command |
| --- | --- |
| `SPC z f` / `C-c z f` | `zoxide-find-file` |
| `SPC z t` / `C-c z t` | `zoxide-travel` — jump to a remembered directory |
| `SPC z d` / `C-c z d` | `zoxide-cd` |
| `M-x dired-jump-with-zoxide` | Pick a zoxide directory and open it directly in Dired |
