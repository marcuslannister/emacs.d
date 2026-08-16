# org-gtd cheatsheet

[org-gtd](https://github.com/Trevoke/org-gtd.el) 4.6.1 owns the GTD process:
capture, clarify, organize, engage. The topic files under `~/org/` stay the
store — clarified single actions and projects are refiled out into them, and the
org-gtd views still find them, because org-gtd v4 selects on the `ORG_GTD`
property across `org-agenda-files` and never binds a path.

Settings live in `lisp/init-local-gtd.el`; the package is pinned by Git tag in
`lisp/package-list.el`. Global keys live in `lisp/init-local-hel.el` with every
other global key. The full plan and its decisions are in
[`org-gtd-pipeline-spec.md`](org-gtd-pipeline-spec.md). org-gtd needs Emacs 29.1
or newer. When it is absent, the module keeps the inbox path correct, reports
the reason, and leaves the optional settings unchanged.

## The loop

| Step | Command | What it does |
| --- | --- | --- |
| Capture | `org-gtd-capture` | Writes to `~/org/gtd/inbox.org`. Do not think here. |
| Clarify | `org-gtd-clarify-item` | Opens the item in a WIP buffer. Edit the title, add notes. |
| Organize | `org-gtd-organize` | Transient menu. Select the type, then refile. |
| Engage | `org-gtd-engage` | The daily view: what you can do now. |
| Process | `org-gtd-process-inbox` | Clarify and organize each inbox item in one loop. |

## Global keys

| Key | Command |
| --- | --- |
| `C-c c` | Command centre (`init-local-gtd-command-center`) |
| `C-c o g c` | Capture to inbox (`org-gtd-capture`) |
| `C-c o g e` | Engage (`init-local-gtd-engage`) |
| `C-c o g i` | Process inbox (`org-gtd-process-inbox`) |
| `C-c o g k` | Clarify at point (`init-local-gtd-clarify-item`) |
| `C-c o g m` | Command centre (`init-local-gtd-command-center`) |
| `C-c o g n` | All next actions (`org-gtd-show-all-next`) |
| `C-c o g p` | All projects (`init-local-gtd-show-all-projects`) |
| `C-c o g s` | Stuck projects (`org-gtd-reflect-stuck-projects`) |
| `C-c o g o` | Organize clarify task (`org-gtd-organize`) |
| `C-c o g a` | Agenda task transient (`org-gtd-agenda-transient`) |
| `C-c o e` | Engage (`init-local-gtd-engage`) |
| `C-c o k` | Clarify at point (`init-local-gtd-clarify-item`) |

The three commands are wrappers. When org-gtd is off, they report why instead of
failing with a void-function error.

## Mode keys

| Where | Key | Command |
| --- | --- | --- |
| Clarify buffer | `C-c c` | Organize the item |
| Clarify buffer | `C-c C-c` | Organize the item (bound by this configuration) |
| Clarify buffer | `C-c C-k` | Cancel |
| Clarify buffer | `C-c d` | Duplicate |
| Agenda | `C-c c` | Task transient for the entry at point |
| Agenda | `C-c .` | Task transient for the entry at point |

`C-c c` opens the command centre globally, organizes an item in a clarify
buffer, and opens the task menu in an agenda buffer.

## Command centre (`C-c c`)

| Group | Key | Action |
| --- | --- | --- |
| Engage | `e` | Daily view |
| | `@` | By context |
| | `n` | All next actions |
| Capture & process | `c` | Capture to inbox |
| | `p` | Process inbox |
| | `k` | Clarify at point |
| Reflect | `a` | Area of focus |
| | `y` | Someday/maybe |
| | `d` | Upcoming delegated |
| | `r` / `R` | Completed items / completed projects |
| Archive | `A` | Archive completed |
| Review | `S` | Stuck items submenu |
| | `M` | Missed items submenu |

## Organize menu (`C-c C-c` in the clarify buffer)

| Group | Key | Type |
| --- | --- | --- |
| Actionable | `q` | Quick action (under two minutes) |
| | `s` | Single action |
| | `d` | Delegate |
| | `c` | Calendar |
| | `h` | Habit |
| Project | `p` | Project (multi-step) |
| | `a` | Add this task to an existing project |
| Non-actionable | `i` | Tickler |
| | `y` | Someday/maybe |
| | `k` | Knowledge to be stored |
| | `t` | Trash |
| Option | `-n` | Update in place (no refile) |

`s`, `p` and `a` ask for a destination heading. That prompt is the point: it
sends the Task into a topic file. Every other type files itself.

## Agenda task transient (`C-c c` in the agenda)

| Key | Action |
| --- | --- |
| `d` / `n` / `w` / `x` | Mark DONE / set NEXT / set WAIT / cancel |
| `t` | Cycle the TODO state |
| `s` | Set date |
| `I` / `O` | Clock in / clock out |
| `e` | Set effort |
| `z` | Add note |
| `a` | Area of focus |
| `c` / `C` | Clarify with refile / clarify in place |

## Keywords

One sequence, in `lisp/init-org.el`:

```elisp
(sequence "TODO(t)" "NEXT(n)" "WAIT(w@/!)" "|" "DONE(d!/!)" "CNCL(c@/!)")
```

These are the same five keywords as org-gtd's default `org-gtd-keyword-mapping`,
so no mapping is set by hand. Org strips the cookies before org-gtd reads them.

## Files

| Path | Content |
| --- | --- |
| `~/org/gtd/inbox.org` | The capture target |
| `~/org/gtd/org-gtd-tasks.org` | `* Actions`; the home for a Task with no topic file |
| `~/org/*.org` | The store: topic files that receive clarified Tasks |

`org-gtd-tasks.org` is written before the refile prompt, so it always exists and
always appears as a candidate. That is correct.
Project creation also prompts for a destination, so a Project can live under a
level-1 heading in a topic file such as `~/org/ai.org`.

## Settings this configuration owns

| Setting | Value | Reason |
| --- | --- | --- |
| `org-gtd-directory` | `~/org/gtd/` | Holds the inbox and the tasks file only. |
| `org-gtd-update-ack` | `"4.6.1"` | Set before `require`, or org-gtd warns on each load. |
| `org-gtd-refile-to-any-target` | `nil` | Obsolete, but read first; its default `t` disables every prompt. |
| `org-gtd-refile-prompt-for-types` | `(single-action project-heading project-task)` | Project creation prompts for a topic-file destination. |
| `org-gtd-archive-location` | `nil` | Keeps the plain `*.org_archive` files working. |
| `org-gtd-organize-hooks` | `nil` | Removes the tag prompt on each clarify. |
| `org-agenda-dim-blocked-tasks` | `nil` | org-edna would wake a slow pass over the full `~/org` scan. |

`org-agenda-files` is rebuilt after each capture and after each refile, through
`init-local-gtd-refresh-agenda-files`, so a new GTD file reaches the views
without a restart.

## Cautions

- **Re-clarify cuts and re-refiles.** With prompting on for its type, the Task
  stays where it is and you answer the prompt again. The `-n` toggle updates it
  in place.
- **Do not put a native Org repeater under an org-gtd project.** The project
  trigger re-fires on each cycle, against a heading Org has already reset.
- **Archiving a project** moves any child task shared with a second project into
  `* Actions` in `org-gtd-tasks.org`, wherever it lived.
- **Do not use `with-org-gtd-context`.** It is a dead macro in 4.x and warns when
  called.
- **`org-gtd-mode` is global.** Its state-change hooks all stop on a heading
  with no `ORG_GTD` property, so the property is the scope.
- When org-gtd is off, `init-local-gtd-unavailable-reason` holds the reason.
