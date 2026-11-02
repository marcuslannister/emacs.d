# Append-and-review note cheatsheet

Karpathy's append-and-review note in one Org file, `~/org/notes.org`. New notes
go on top. When a note is still useful at review, move it back to the top.
Notes that you do not move sink to the bottom.

Code is in `lisp/init-local-append-review.el`. Keys are in
`lisp/init-local-hel.el`. Research is in
[`research/append-and-review-note-org.md`](research/append-and-review-note-org.md).

## The file

```org
* Today
** note you will work on today
* Inbox
** newest note
** older note
```

- `* Today` and `* Inbox` are top-level sections. Notes are level-2 headings.
- Do not start a section name with a todo keyword (`TODO`, `NEXT`, ...). Org
  then reads the section as a task, and it shows in the agenda.
- Capture looks for the heading `Inbox` by name. Do not rename it.
- `SPC n u` works on a note. On a section heading it stops with an error.

## Keys

| Key | Command | What it does |
| --- | --- | --- |
| `SPC n o` | `init-local-append-review-open` | Open `~/org/notes.org`. |
| `SPC n n` | `init-local-append-review-capture` | Capture a new note at the top of `Inbox`. |
| `SPC n u` | `init-local-append-review-to-top` | Select a section, then move the note at point to its top. |

In the capture buffer, `C-c C-c` saves the note and `C-c C-k` cancels it.
Capture template key `a` also works from `org-capture`.

## The loop

1. **Append.** `SPC n n`, type the note, `C-c C-c`.
2. **Review.** `SPC n o`, then read from the top down.
3. **Keep.** On a note that is still useful: `SPC n u`, select `Inbox`.
4. **Plan the day.** On a note for today: `SPC n u`, select `Today`.
5. **Done.** Delete the note, or leave it to sink.
