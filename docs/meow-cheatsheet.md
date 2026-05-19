# Meow Cheatsheet

Personal reference for the meow bindings configured in `lisp/init-local-meow.el`.

## Recent Customizations

| Key | Now binds to             | Previously              | Why                          |
|-----|--------------------------|-------------------------|------------------------------|
| `;` | `move-beginning-of-line` | `meow-reverse`          | Vim-like line-start motion   |
| `$` | `move-end-of-line`       | (unbound)               | Vim-like line-end motion     |
| `R` | `meow-reverse`           | `meow-swap-grab`        | Free up `R`; keep reverse    |
| `i` (MOTION) | `meow-normal-mode` | `meow-insert` (motion)  | `i` enters NORMAL from MOTION |
| `SPC d d` | `kill-whole-line`   | (n/a)                   | Quick line kill              |

`meow-swap-grab` is no longer bound — invoke with `M-x` if needed.

## Motion (Normal state)

| Key   | Action                                  |
|-------|-----------------------------------------|
| `h/j/k/l` | left / down / up / right (cursor)   |
| `H/J/K/L` | extend selection left/down/up/right |
| `;`   | beginning of line                       |
| `$`   | end of line                             |
| `<`   | beginning of buffer                     |
| `>`   | end of buffer                           |
| `Q`   | go to line (prompt)                     |
| `f`   | find char forward                       |
| `t`   | till char forward                       |
| `T`   | till char + extend                      |
| `n` / `N` | search next / pop search            |
| `v` or `/` | visit (search-and-jump)            |

## Word / Symbol Selection

| Key | Action                                       |
|-----|----------------------------------------------|
| `w` | mark word at point                           |
| `W` | mark symbol at point                         |
| `e` | select / extend to next word end             |
| `E` | select / extend to next symbol end           |
| `b` | select / extend back to previous word start  |
| `B` | back-symbol                                  |

Tip: press `e` repeatedly to grow the selection word-by-word.

## "Thing" Selection (objects)

Trigger with `,` (inner) or `.` (bounds), then a char.

| Char | Thing       |
|------|-------------|
| `.`  | sentence    |
| `p`  | paragraph   |
| `l`  | line        |
| `e`  | symbol      |
| `d`  | defun       |
| `r/s/c` | round/square/curly brackets |
| `g`  | string      |
| `w`  | window      |
| `b`  | buffer      |

Examples:
- `. .` → select whole sentence (with trailing punctuation)
- `, .` → select inner sentence
- `. p` → select whole paragraph
- `, r` → inner of `( ... )`

`[ <char>` / `] <char>` select from point to beginning/end of a thing.

## Expand (numeric hints)

After a motion that shows hints (e.g. `e`, `b`, `f`), press `1`–`9`
to jump and select up to the Nth hint at once (`meow-expand-1` …
`meow-expand-9`).

## Editing

| Key | Action                                    |
|-----|-------------------------------------------|
| `i` | insert before                             |
| `a` | append after                              |
| `I` | open line above (insert)                  |
| `A` / `o` | open line below                     |
| `c` | change selection                          |
| `s` | **kill selection** (delete + yank ring)   |
| `x` | delete one char forward (or selection without ring) |
| `D` | backward delete                           |
| `r` | replace char                              |
| `m` | join lines                                |
| `u` / `U` | undo / undo in selection            |
| `p` / `P` | yank / yank-pop                     |
| `y` | save (copy) selection                     |
| `&` | query-replace                             |
| `%` | query-replace-regexp                      |

**Important:** to delete a selection, use `s` (not `x`).
`x` only deletes the character under the cursor.

## Selection Management

| Key | Action                                      |
|-----|---------------------------------------------|
| `g` | cancel selection                            |
| `R` | reverse — swap point and mark (extend the other way) |
| `z` | pop previous selection                      |
| `Z` | pop all selections                          |
| `G` | grab (stash region as secondary selection)  |
| `Y` | sync grab with current region               |

Grab workflow (swap two regions): select A → `G`, select B → invoke `M-x meow-swap-grab`.

## Modes

- `i` (NORMAL) → INSERT
- `<escape>` is ignored (no accidental mode flips)
- `i` (MOTION) → NORMAL (custom override)

## Leader (SPC) — Highlights

| Keys       | Action                              |
|------------|-------------------------------------|
| `SPC SPC`  | save buffer                         |
| `SPC :`    | M-x                                 |
| `SPC .`    | find-file                           |
| `SPC ,`    | switch-buffer                       |
| `SPC d d`  | kill whole line                     |
| `SPC d w`  | delete trailing whitespace          |
| `SPC g s`  | magit status                        |
| `SPC p p`  | project-find-file                   |
| `SPC w v/h`| split window right / below          |
| `SPC w q`  | close current window                |
| `SPC q q`  | quit Emacs                          |
| `SPC ?`    | meow cheatsheet (interactive)       |

See `init-local-meow.el` for the full leader map.
