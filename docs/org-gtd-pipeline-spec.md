# org-gtd pipeline: implementation specification

Decision-complete specification for adding org-gtd to this configuration as the
capture -> clarify -> organize -> engage pipeline, with `org-gtd-directory` at
`~/org/gtd/` and clarified Tasks refiled out into the existing topic files under
`~/org/`.

**Nothing here is implemented yet.** This document is the output of the
wayfinding map [Org GTD Pipeline Wayfinding][map], whose ten decision tickets
are all closed; each section below cites the ticket that settled it. The build
and the data migration are a separate piece of work.

Written against **org-gtd 4.6.1 / org-edna 1.1.2 / Org 9.8.7 / Emacs 31.0.91**.

[map]: https://github.com/marcuslannister/emacs.d/issues/15

---

## 1. The package pin

org-gtd is pinned by tag, not taken from MELPA. After 4.1.0 the type registry drops `project-heading` and `project-task`, and projects then stop asking for a topic file — silently, which defeats the destination (#16). `maybe-require-package` enforces a minimum version only, so MELPA cannot be held.

Add to `lisp/package-list.el`, beside the other pinned Git packages:

```elisp
;; GTD process layer.  Pinned to a tag: `org-gtd-refile-prompt-for-types' is
;; obsolete from 4.1.0, and on master the type registry migration silently skips
;; `project-heading' and `project-task', so projects would auto-file into
;; org-gtd-tasks.org instead of prompting for a topic file.  4.6.1 is the newest
;; release; move the tag deliberately, and re-test the refile prompt when you do.
;; Dependencies (org-edna from GNU ELPA, transient) stay with package.el.
(async-installer-git-add "https://github.com/Trevoke/org-gtd.el.git"
                         :tag "4.6.1"
                         :main "org-gtd.el")
```

Declare **only** org-gtd. org-edna 1.1.2 arrives from GNU ELPA as a dependency, and both archives are already configured (#17).

---

## 2. The new module: `lisp/init-local-gtd.el`

It owns the `org-gtd-*` settings and two mode-map keys. Nothing else. It can be deleted in one step and the store still works.

```elisp
;;; init-local-gtd.el --- org-gtd capture/clarify/organize/engage  -*- lexical-binding: t; -*-
;;; Commentary:
;; org-gtd owns the process.  The topic files under `org-directory' stay the
;; store: clarified single actions and projects are refiled out into them, and
;; org-gtd's views still find them, because org-gtd v4 selects on the ORG_GTD
;; property across `org-agenda-files' and never binds a path (#16).
;;
;; This module owns only `org-gtd-*' settings and its own mode-map keys, so it
;; can be deleted in one step.  Global keys live with every other global key, in
;; `init-local-hel.el'.  When org-gtd is absent the module keeps the inbox path
;; correct, reports why, and leaves the optional settings unchanged.
;;; Code:

(require 'org)

(defvar init-local-gtd-unavailable-reason nil
  "Why org-gtd support is off, or nil when it is on.")

(defun init-local-gtd--mark-unavailable (reason)
  "Record REASON and leave the optional settings untouched."
  (setq init-local-gtd-unavailable-reason reason)
  (message "init-local-gtd: org-gtd support disabled -- %s" reason))

(defun init-local-gtd-refresh-agenda-files (&rest _)
  "Rebuild `org-agenda-files' so new GTD files reach the views.
`org-agenda-files' is computed once at load, so the inbox org-gtd creates
on the first capture is invisible to every view until a restart."
  (interactive)
  (when (fboundp 'init-local-org-agenda-files)
    (setq org-agenda-files (init-local-org-agenda-files))))

(defun init-local-gtd--settings ()
  "Apply the org-gtd settings this module owns."
  ;; Acknowledge the installed version, or org-gtd warns on every load.
  (setq org-gtd-update-ack "4.6.1"
        ;; Obsolete since 4.0.0, but `org-gtd-refile--should-prompt-p' reads it
        ;; FIRST, and its default t disables every prompt.  Load-bearing.
        org-gtd-refile-to-any-target nil
        ;; Symbols, not strings: the test is `memq'.  A string list fails in
        ;; silence and sends every Task into org-gtd-tasks.org (#20).
        org-gtd-refile-prompt-for-types '(single-action project-heading project-task)
        ;; nil restores plain `org-archive-location', which is what keeps
        ;; software.org_archive working (#16).
        org-gtd-archive-location nil
        ;; The default is (org-set-tags-command), which stops every clarify to
        ;; ask for tags; this store almost never tags a heading.  The refresh
        ;; below replaces it, so organize also repairs `org-agenda-files' (#21).
        org-gtd-organize-hooks '(init-local-gtd-refresh-agenda-files)
        ;; org-edna makes `org-blocker-hook' non-nil, which wakes the agenda
        ;; blocked-task dim pass -- three property reads per entry over the
        ;; recursive ~/org scan, dead here until now (#17).
        org-agenda-dim-blocked-tasks nil)
  ;; Same job after a capture, through a documented Org hook rather than advice.
  (add-hook 'org-capture-after-finalize-hook
            #'init-local-gtd-refresh-agenda-files))

(defun init-local-gtd--bind-keys ()
  "Bind the two keys that belong to org-gtd's own maps.
The global keys live in `init-local-hel.el' with every other global key."
  ;; org-gtd binds C-c C-k (cancel) and C-c d (duplicate) in the clarify buffer,
  ;; but never binds `org-gtd-organize' -- the command that files the Task, and
  ;; the one pressed most.  Out of the box it is M-x only.
  (keymap-set org-gtd-clarify-mode-map "C-c C-c" #'org-gtd-organize)
  ;; The same key as the global one, so C-c c always opens the GTD menu that
  ;; fits where you are: the command centre everywhere, the Task menu here.
  (with-eval-after-load 'org-agenda
    (keymap-set org-agenda-mode-map "C-c c" #'org-gtd-agenda-transient)))

(defun init-local-gtd--initialize ()
  "Enable org-gtd support, or report why it is off."
  (setq org-gtd-directory (expand-file-name "gtd/" org-directory))
  (cond
   ((version< emacs-version "29.1")
    (init-local-gtd--mark-unavailable "Emacs 29.1 or newer is required"))
   ;; org-gtd arrives through async-installer, not package.el, so this is the
   ;; guard -- NOT `maybe-require-package', which would fetch it from MELPA and
   ;; defeat the version pin.
   ((not (require 'org-gtd nil t))
    (init-local-gtd--mark-unavailable "the org-gtd package is not installed"))
   (t
    (init-local-gtd--settings)
    (init-local-gtd--bind-keys)
    (org-gtd-mode 1))))

(init-local-gtd--initialize)

(provide 'init-local-gtd)
;;; init-local-gtd.el ends here
```

**Two refinements to record, both inside the intent of the decision they refine.**

- #21 decided `org-gtd-organize-hooks` should be `nil`, to remove the tag prompt, and separately that the module should refresh `org-agenda-files` after capture and after organize. Setting the hook to the refresh function does both, and uses a documented seam instead of advising a private function. The tag prompt is still gone.
- `org-gtd-mode` is enabled **globally**. Its four state-change hooks all stop at once on a heading with no `ORG_GTD` property, so the property is the scope. Scoping by hand means copying org-gtd's logic and then keeping the copy correct.

Do **not** use `with-org-gtd-context`: it is a dead macro in 4.x that warns when called.

**IDs**: org-gtd mints its own — a slug of the heading plus an ISO stamp, `Buy-a-new-coffee-grinder-2026-08-13-23-00-44`, not a UUID — and writes them into its `TRIGGER`, `ORG_GTD_DEPENDS_ON` and `ORG_GTD_BLOCKS` properties. Accepted. The Task Table reads an ID as text.

---

## 3. Edits to the files that already exist

### `lisp/init-local.el`

Add after `(require 'init-local-hel)` at line 416:

```elisp
(require 'init-local-gtd nil t)
```

Org (140), Vulpea (141) and Hel (416) all exist by then, and a failure inside the module cannot stop them. **`lisp/init-local-keybinding.el` is dead code** — line 480 comments out its `require` — so nothing goes there.

### `lisp/init-org.el`

| Line | Change |
| --- | --- |
| 165-169 | Replace the three sequences with one: `(setq org-todo-keywords '((sequence "TODO(t)" "NEXT(n)" "WAIT(w@/!)" "|" "DONE(d!/!)" "CNCL(c@/!)")))`. Write the `sequence` symbol: a bare list loses its first keyword in the Task Table's parsing (#18). Keep the cookies: Org strips them to bare keywords, and org-gtd reads its own `org-gtd-keyword-mapping`, so they are invisible to it (#19). |
| 171 | **Delete** the `org-todo-keyword-faces` form. `init-local-themes.el:60` re-sets the whole variable after modus-themes loads, so this one never takes effect. One place only, and it is the theme file. |
| 182 | **Delete** `org-stuck-projects`. It matches `PROJECT`, which has zero Tasks now and stops existing. org-gtd finds stuck projects through the `ORG_GTD` property. |
| 191-260 | **Delete** the `g` GTD view. Keep `N`. Leave the `g` key free. |

### `lisp/init-local-org.el`

| Line | Change |
| --- | --- |
| 6 | Point `org-default-notes-file` at org-gtd's inbox when `~/org/inbox.org` is deleted. |
| 8-11 | Extract into `init-local-org-agenda-files`, a named function that returns the list and filters both `/.stversions/` and the GTD inbox. Line 8 then calls it. Ownership stays here; the GTD module only calls it. |
| 220-231 | The surviving `p` view names retired keywords in three skip functions. Rewrite `'("TODO" "NEXT" "PROJECT" "DELEGATED")` to `'("TODO" "NEXT" "WAIT")` in all three, and **delete its `Inbox entries` block**: it matches the `INBOX` tag, which occurs nowhere in `~/org/`, and org-gtd owns the inbox now. |
| 255 | **Delete** the commented-out `svg-tag-mode` block. Dead code naming keywords that will not exist. |
| 343-346 | **Delete** capture template `i`. Template `t` goes with it; `n` stays. org-gtd's own `i` and `l` templates are **not** customised — reach them through `org-gtd-capture`. |

### `lisp/init-local-hel.el`

Inside the `hel-keymap-global-set` form (Org section, lines 141-158):

```elisp
    "C-c c"   #'org-gtd-command-center
    "C-c o e" #'org-gtd-engage
    "C-c o k" #'org-gtd-clarify-item
```

Delete `"C-c o n l" #'org-now-link` and `"C-c o n t" #'org-now` (lines 157-158).

In the `which-key-add-key-based-replacements` form: add `"C-c c"` → `GTD`, `"C-c o e"` → `Engage`, `"C-c o k"` → `Clarify at point`; delete `"C-c o n"`, `"C-c o n l"` and `"C-c o n t"` (lines 360-362). Delete the group with its children, or which-key shows an empty menu.

**`C-c d` is not available** and was never a candidate: it already holds eight edit, Denote and Dired keys, and org-gtd's clarify map binds it too. **org-now needs no package removal** — it is declared nowhere in `lisp/`; the two dead bindings in `init-local-keybinding.el:100-101` may go with the same edit.

### `lisp/init-local-themes.el`

Rewrite the block at 60-69 to the five live keywords. `TODO`, `NEXT`, `DONE` keep their colours. `WAITING` becomes `WAIT` and keeps cyan. `CANCELLED` becomes `CNCL` and keeps dim. Drop `HOLD`, `PROJECT`, `DELEGATED`.

---

## 4. The data migration, in order

**The rewrite is 20 headings in 5 files.** `PROJECT` and `DELEGATED` do not exist in the store at all.

| File | `HOLD`→`WAIT` | `WAITING`→`WAIT` | `CANCELLED`→`CNCL` |
| --- | --- | --- | --- |
| `software.org` | 9 | 1 | 1 |
| `network.org` | 4 | — | — |
| `bookmark.org` | — | — | 3 |
| `ai.org` | — | — | 1 |
| `hardware.org` | — | — | 1 |

`gtd-keyword-rewrite.el` lives at the repository root, beside `test-startup.sh`, and runs once as `emacs -Q --batch -l gtd-keyword-rewrite.el`. It is committed as the record of what was done, not built for re-runnability — that comes free, because it matches only old keywords.

It selects with `org-map-entries`, matched on the TODO keyword, with `org-inhibit-logging` bound to `t`. **Not `sed`, `sd` or any text replace**: the old keywords appear far more often in prose and logbooks than in headings — `HOLD` 13 headings against 26 occurrences, `WAITING` 1 against 20, `CANCELLED` 6 against 16 — so a text replace would corrupt about 42 places, including the 24 logbook lines kept as history. It prints every heading it changes; that output goes in the commit message.

It takes the five file names literally. It does not scan a directory, so `.stversions` (106 old copies that still hold old keywords), `~/org/org-supertag/` (no Org files) and `software.org_archive` (zero old keywords) are excluded by construction. `todo.org` is excluded too: `** Organization` (`6B6FB404-85A4-4212-B9D0-D4C2C527DD9D`) has no TODO keyword and holds the clock history.

### Run order

1. **Rename `* Tasks` / `** Organization` in `diary.org`.** It collides with the same path in `todo.org` in the refile prompt, and that is the one collision that costs something invisible. Before the first clarify (#24).
2. Quit Emacs on both Macs. Pause Syncthing on both.
3. `cp -a ~/org ~/org-backup-<date>`.
4. Take the Layer 1 counts.
5. Run `gtd-keyword-rewrite.el` under `emacs -Q --batch`. **Data before configuration**: `-Q` loads nothing, so no keyword needs to be defined; the script names both the old and the new. The other order leaves your live Emacs holding 20 headings whose keywords it no longer defines.
6. Land the configuration change. Start Emacs.
7. Take the Layer 1 counts again, then the Layer 2 counts.
8. Clarify the 4 Open Tasks in `inbox.org`; move the 2 `:NOTE:` headings out of `refile.org`; then delete `inbox.org`, `refile.org` and `now.org` (empty).
9. Resume Syncthing on both Macs.

`~/org` is a Syncthing folder (`type="sendreceive"`), so the second Mac receives the result. **There is no second run.**

### Rollback

`~/org` is not a Git repository, so the dated copy is the primary. To roll back: quit Emacs, `mv ~/org ~/org-failed-<date>` — **rename it, never delete it** — `cp -a ~/org-backup-<date> ~/org`, resume Syncthing. For one bad file, `~/org/.stversions` holds a timestamped copy.

---

## 5. The verification plan

| Check | Expectation |
| --- | --- |
| `./test-startup.sh` | green |
| ERT under `tests/` | green, unchanged. #18 proved no existing test breaks: every test binds its own workflow, and nothing under `tests/` loads `init-org.el` |
| New: `tests/init-local-gtd-tests.el` | the settings are applied when org-gtd is present; when it is absent, `org-gtd-directory` is still set, `init-local-gtd-unavailable-reason` records why, and no optional `org-gtd-*` setting is written |
| Manual end-to-end | capture → clarify → organize as a single action → the Task lands in the chosen topic file → `org-gtd-engage` shows it |
| Task Table keyword check | every Open Task shows `TODO`, `NEXT` or `WAIT`. Any other state is a missed heading (#18) |
| Layer 1 counts, before and after | Snapshot at #19/#22: `TODO` 55, `NEXT` 49, `DONE` 245, `WAIT` 0+14, Open Tasks 118. Store at rewrite time: `NEXT` 48, `DONE` 246, two pre-existing `WAIT` headings (`other.org:68`, `software.org:1039`), Open Tasks 119. The rewrite itself was 20/20. |
| Layer 2 counts, before and after | agenda entries and Task Table Open Tasks identical |

**Tolerance is zero.** Any difference is a fault to investigate, not a variance to accept.

---

## 6. Cautions to carry into the build

- **Repeaters under projects.** org-gtd stamps `TRIGGER: self org-gtd-update-project-after-task-done!` onto every project task. A native Org repeater under an org-gtd project re-fires that trigger on each cycle, against a heading Org has already reset; the org-edna manual warns against the combination. Only 4 repeaters exist in `~/org/`, in 3 files, and none sits in a project. A written caution, not a build step (#17).
- **Re-clarify.** Re-clarifying a Task that lives in a topic file cuts and re-refiles it. With prompting on for its type it stays put; with prompting off it returns to `org-gtd-tasks.org`; the organize transient's `-n` toggle updates in place. The configuration above keeps it safe, at the cost of re-answering the prompt (#20).
- **Archiving a project** physically cuts any child task still shared with another project and pastes it under `* Actions` in `org-gtd-tasks.org`, wherever it lived. Unconditional, but only for multi-project tasks (#16).
- **`org-gtd-tasks.org` is seeded whatever you do.** `org-gtd-refile--do` writes the `* Actions` heading with `ORG_GTD_REFILE: Actions` before it prompts, so the file exists and appears as a refile candidate even when every type prompts. That is correct: it is the destination for a Task with no topic file home (#24).
- **`org-id-locations`.** While clarifying, `org-gtd-id-get-create` registers an ID against the literal string `"Org GTD WIP buffer"`. The refile corrects it. Nothing broke in testing, but that is where a crash mid-clarify would leave a bad row (#20).
- **`bh/agenda-sort` needs no work.** It is global, and `org-gtd-engage.el` overrides no sorting, so engage already inherits the Norang order. Do not re-wire it (#25).

---

## 7. Left open on purpose

- **`habits.org` against the org-gtd habit type.** The file is 9 lines with one `NEXT` heading, no `:STYLE: habit` property exists anywhere in `~/org/`, and `org-habit` is not loaded. Low stakes, undecided.
- **The 13 `HOLD` Tasks.** They become `WAIT` by the rewrite. org-gtd's someday type is a better home, but that is a re-clarify one at a time, after the pipeline runs — not a migration step.
- **The 15 remaining ambiguous refile labels.** Measured and accepted: 16 of 1,150 labels collide, and `diary.org` fixes the only costly one. The rest are notes and bookmarks. Recorded as a judgement, not a defect, so it is not re-opened (#24).
- **A replacement agenda view.** The `g` view is deleted with no replacement, because every live block has a home. If a real gap appears after a week of use, add one plain `org-agenda-custom-commands` entry then. Do not use org-gtd's view language: every entry point in `org-gtd-view-language.el` is private (#25).
- **The review layer** — areas of focus, horizons, someday review, stuck-project reflection — stays out of scope. It is a habit change, and it needs the pipeline running first.
