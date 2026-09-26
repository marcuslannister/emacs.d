---
name: org-case-check
description: "Upcase damage check for ~/org. Use when the user asks to check org files for upcased text, after a case-guard save block or log entry, or when org-gtd projects go missing from the agenda."
---

# org-case-check

Report upcase damage in `~/org`: each damaged file or buffer, its match count, and the
matching lines. `scan.el` in this folder does the scan with the canary patterns from
`lisp/init-local-case-guard.el`.

Report only. The undo list of the live buffer is the only history of `~/org`, so the user
repairs the damage with undo in Emacs. Leave every buffer and file in `~/org` unchanged: a
save or a revert deletes that history.

## Steps

### 1. Scan the files on disk

Run from the repository root:

```sh
emacs -Q --batch -L lisp -l .claude/skills/org-case-check/scan.el -f org-case-check-files
```

Done when the command exits. No output means every file is clean.

### 2. Scan the live buffers

Damage is in a buffer before it is on disk. Run from the repository root:

```sh
emacsclient -s "/tmp/emacs$(id -u)/server" --eval "(progn (load \"$PWD/.claude/skills/org-case-check/scan.el\") (org-case-check-buffers))"
```

The server socket is in `/tmp`, but on macOS a plain `emacsclient` looks in `$TMPDIR` and
cannot find it, so `-s` gives the path.

Done when the command returns. `""` means every buffer is clean. If there is no Emacs server,
tell the user that the buffers are not checked.

### 3. Report

Give each damaged file and buffer with its lines. A count at or above the threshold blocks
the save. Show the last entries of the file in `ml-case-guard-log-file`, if it exists.
