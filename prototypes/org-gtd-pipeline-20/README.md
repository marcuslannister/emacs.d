# PROTOTYPE — one Task from capture to a topic file

Throwaway rig for wayfinder ticket
[#20](https://github.com/marcuslannister/emacs.d/issues/20), on the map
[Org GTD Pipeline Wayfinding](https://github.com/marcuslannister/emacs.d/issues/15).
Not part of the configuration. Nothing here is loaded by `init.el`.

The rig runs in a scratch Emacs against a synthetic Org store. It touches
neither `~/org/` nor `~/.emacs.d/`.

## How to run

```sh
mkdir -p /tmp/org-gtd-proto/emacs /tmp/org-gtd-proto/org/gtd
cp prototypes/org-gtd-pipeline-20/*.el /tmp/org-gtd-proto/emacs/
emacs -Q --batch --eval '(progn (require (quote package))
  (setq package-user-dir "/tmp/org-gtd-proto/emacs/elpa/")
  (setq package-archives (quote (("gnu" . "https://elpa.gnu.org/packages/")
    ("melpa-stable" . "https://stable.melpa.org/packages/")
    ("melpa" . "https://melpa.org/packages/"))))
  (setq package-archive-priorities (quote (("melpa-stable" . 30) ("gnu" . 20) ("melpa" . 0))))
  (package-initialize) (package-refresh-contents) (package-install (quote org-gtd)))'
emacs -Q --batch -l /tmp/org-gtd-proto/emacs/make-tree.el
emacs -Q --batch -l /tmp/org-gtd-proto/emacs/drive.el    # capture -> clarify -> topic file -> views
emacs -Q --batch -l /tmp/org-gtd-proto/emacs/drive2.el   # project cookie, re-clarify
emacs -Q --batch -l /tmp/org-gtd-proto/emacs/drive3.el   # refile prompt cost and legibility
```

`make-tree.el` rebuilds the synthetic store. Delete
`/tmp/org-gtd-proto/org/gtd/inbox.org` and `org-gtd-tasks.org` between runs.

## Files

| File | What it is |
| --- | --- |
| `init.el` | The configuration the map proposes, in miniature |
| `make-tree.el` | Synthetic `~/org` lookalike: same 30 file names, same 1,151 headings, no real content |
| `drive.el` | Capture, clarify, organize as single action, then the two views |
| `drive2.el` | Project into a topic file, agenda `DONE`, progress cookie, and three re-clarify paths |
| `drive3.el` | Refile-target count, build time, and label legibility |

## What it ran against

org-gtd 4.6.1 (melpa-stable) / Org 9.8.7 / Emacs 31.0.91.

The findings are on issue #20.
