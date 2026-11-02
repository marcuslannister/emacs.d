# The append-and-review note in Emacs Org mode

Research date: 2026-11-01. Tested with GNU Emacs 31.1.50 and Org 9.8.7 (the Org that ships with that Emacs).

Source abbreviations:

- [K] Karpathy, "The append-and-review note", 19 Mar 2025: https://karpathy.bearblog.dev/the-append-and-review-note/
- [OM:node] Org manual node, at `https://orgmode.org/manual/<node>.html`
- [EM:node] GNU Emacs manual node, at `https://www.gnu.org/software/emacs/manual/html_node/emacs/<node>.html`
- [src:file:line] Org source file, Org 9.8.7 as shipped in Emacs 31. Upstream: https://git.savannah.gnu.org/cgit/emacs/org-mode.git/tree/lisp/ . Line numbers can differ in other versions.

## 1. The method (primary source)

- **One note.** Karpathy keeps "one single text note in the Apple Notes app just called 'notes'". More notes and folders cost "way too much cognitive bloat". One note makes "CTRL+F … simple and trivial". [K]
- **Tool.** Apple Notes. He says Apple gives "optional offline editing, syncing between devices, and backup". [K]
- **Append.** He appends each idea or todo "to the note on top, simply as text", on the computer or on the iPhone. [K]
- **No metadata.** He does not add "dates, links, concepts, tags" by default. The only exception is prefix tags such as "watch:", "listen:", and "read:", so that CTRL+F finds them. [K]
- **Sinking.** New items go on top, so older items "sink towards the bottom, almost as if under gravity". [K]
- **Review.** "Every now and then" he scrolls down and skims. [K]
- **Rescue.** If an item "deserves to not leave my attention", he moves it "towards the top by simply copy pasting". He sometimes merges, groups, or edits related items. [K]
- **Delete.** He deletes "only rarely". Items that do not get attention "continue to sink. They are never lost". [K]
- **Uses.** Random ideas, movie and book tips, a daily TODO list, draft tweets, quotes, numbers from papers, shell commands, experiment logs, a scratch surface for copy and paste, and a "brain dump" when stressed. [K]
- **Effect.** After he writes an item down, he can "wipe my working memory" and focus on other work. [K]

## 2. Map each part to Emacs and Org

| Method part | Org feature | Source |
|---|---|---|
| One note | One Org file. Optionally `org-default-notes-file`. | [OM:Setting-up-capture] |
| Append on top | `org-capture` with a `(file ...)` target and `:prepend t` | [OM:Template-elements], [src:org-capture.el:1327-1330] |
| Plain text, no metadata | Template `"* %?"`. Add `%U` only if you want a date. | [OM:Template-expansion] |
| Prefix tags (`read:`) | Type them in the headline text. Search with `org-occur`. | [OM:Sparse-Trees] |
| Review by scroll | Normal scrolling. `TAB` / `S-TAB` folding is optional. | Unverified (not checked in a manual node for this report) |
| Rescue to top | No dedicated built-in command. Use `org-refile-reverse` to a file-level target, or the helper below. `M-<up>` moves one step only. | [OM:Refile-and-Copy], [OM:Structure-Editing], [src:org-refile.el:333-334, 584-589] |
| Merge or edit | Normal editing. `C-c C-x C-w` / `C-c C-x C-y` to cut and paste subtrees. | [OM:Structure-Editing] |
| Rare delete | `C-c C-x C-w` (`org-cut-subtree`), or archive with `C-c $` | [OM:Structure-Editing], [OM:Moving-subtrees] |
| CTRL+F | `C-s` (isearch), `M-s o` (`occur`), `C-c / r` (`org-occur`) | [EM:Other-Repeating-Search], [OM:Sparse-Trees] |

### 2.1 Capture at the top

- Template types: `entry` is "An Org mode node, with a headline", filed "as the child of the target entry or as a top-level entry". `item` is "A plain list item, placed in the first plain list at the target location". `plain` is "Text to be inserted as it is." [OM:Template-elements]
- Target `(file <file-spec>)`: "Text will be placed at the beginning or end of that file." [OM:Template-elements]
- Target `(file+headline <file-spec> "node headline")`: the entry becomes a child of that heading. [OM:Template-elements] Use it only if you want one parent heading. For Karpathy's flat note, `(file ...)` is closer.
- A relative file name "is taken as relative to org-directory". An empty string means `org-default-notes-file`. [OM:Template-elements]
- `:prepend`: "Normally new captured information will be appended at the target location … Setting this property changes that." [OM:Template-elements]
- What `:prepend` does with a `(file ...)` target: Org goes to `point-min`, then to the first heading (`outline-next-heading`), and inserts there. [src:org-capture.el:1327-1330, function `org-capture-place-entry`] Result: file header lines such as `#+TITLE:` stay at the top, and the new entry goes above the old first entry. I confirmed this in a test (section 3).
- `%T` is a timestamp with date and time. `%u` / `%U` are "Like `%t', `%T' above, but inactive timestamps." `%?` sets the cursor position after expansion. [OM:Template-expansion] Inactive timestamps do not put the entry in the agenda. Unverified in the cited node; the agenda behavior is in [OM:Timestamps] (not fetched for this report).
- `:empty-lines`: "the number of lines to insert before and after the new item. Default 0". `:empty-lines-before` and `:empty-lines-after` override it. [OM:Template-elements]
- `:immediate-finish`: "do not offer to edit the information, just file it away immediately." It is useful only when the template needs no typed input. [OM:Template-elements] Do not use it with `%?`.
- `C-c C-c` finishes the capture. `C-c C-k` aborts it. `C-u M-x org-capture` visits the target of a template, so you can open the note for review. [OM:Using-capture]
- The manual suggests a global key, for example `(global-set-key (kbd "C-c c") #'org-capture)`. [OM:Activation]

### 2.2 Rescue an item to the top

- `M-<up>` (`org-move-subtree-up`) does a "swap with previous subtree of same level". [OM:Structure-Editing] It moves one step per call (a numeric prefix moves ARG steps). [src:org.el:7313-7316] It is slow for an item deep in a big file.
- `org-metaup` (`M-<up>`) calls `org-move-subtree-up` on a headline, and moves table rows or list items in other contexts. [src:org.el:17522-17531], [src:org-keys.el:445]
- `M-S-<up>` is `org-shiftmetaup`, not a subtree-to-top command. [src:org-keys.el:456]
- `org-refile` (`C-c C-w`) files the entry under a target heading; "Depending on org-reverse-note-order, it is either the first or last sub-item." [OM:Refile-and-Copy]
- `org-refile-reverse` (`C-c C-M-w`) temporarily toggles `org-reverse-note-order`, so it can "prepend it as the first entry". [OM:Refile-and-Copy]
- A file-level target exists only when `org-refile-use-outline-path` is `file` (or `buffer-name`, `full-file-path`, `title`). Then Org adds the file itself as a target with no position. [src:org-refile.el:333-345] The docstring says: "you can also stop the completion after the file name, to get entries inserted as top level in the file." [src:org-refile.el:149-156]
- With no position and reversed order, refile goes to `point-min`, then to the first heading, and pastes the subtree at level 1. [src:org-refile.el:584-591]
- Conclusion: Org has no single built-in "move subtree to top of file" command. `C-c C-M-w` plus a file-level target does the job, but it needs refile settings and a completion step each time. The helper in section 3 calls the same refile code with a fixed target.

### 2.3 Archive or delete

- `C-c C-x C-w` (`org-cut-subtree`): "Kill subtree, i.e., remove it from the buffer but save in kill ring." [OM:Structure-Editing]
- `C-c C-x C-s` or `C-c $` (`org-archive-subtree`) moves the subtree "to the location given by org-archive-location". [OM:Moving-subtrees]
- Karpathy rarely deletes. [K] Archiving moves text out of the single note, so it breaks the "never lost" search in one file. This is a design note, not a manual claim.

### 2.4 Search

- `C-s` (isearch) is the direct CTRL+F equivalent. Unverified (isearch node not fetched for this report; it is standard Emacs).
- `M-s o` (`occur`): "display a list showing each line in the buffer that contains a match". [EM:Other-Repeating-Search]
- `C-c / r` or `C-c / /` (`org-occur`) "shows a sparse tree with all matches". `M-g n` / `M-g p` jump between matches. [OM:Sparse-Trees]
- Optional: `consult-line` from the third-party Consult package. Not part of Emacs or Org.

### 2.5 Capture from outside Emacs (short)

- org-protocol: a browser bookmarklet calls `org-protocol://capture?template=X&url=…`, which opens a capture buffer with a template. [OM:The-capture-protocol] It needs `emacsclient` and a running Emacs server.
- Org Mobile: "a protocol for synchronizing Org files between Emacs and other applications, e.g., on mobile devices." [OM:Org-Mobile] The manual does not name a maintained phone app. Third-party apps (for example beorg, Orgzly) are outside the scope of this report. Unverified.
- Speed Keys: single keys on a headline, disabled by default; enable with `org-use-speed-commands`. [OM:Speed-Keys] Useful for fast review.

## 3. Minimal config

This config uses the shipped version in `lisp/init-local-append-review.el`: capture template `a` into the `Inbox` section of `~/org/notes.org`, Hel `C-c n n` to capture, `C-c n o` to open the file, and `C-c n u` to move the heading at point to the top of a section (Today or Inbox). Tests are in `tests/init-local-append-review-tests.el`. The generic example below uses other keys.

```elisp
;; One note file. Relative names resolve against `org-directory'.
(setq org-capture-templates
      '(("n" "Note (top of notes.org)" entry
         (file "notes.org")
         "* %?"            ; plain text, no metadata (use "* %?\n%U" for a date)
         :prepend t)))
(global-set-key (kbd "C-c c") #'org-capture)

(defun my/org-subtree-to-top ()
  "Move the subtree at point to the top of the current Org file."
  (interactive)
  (let ((org-reverse-note-order t))
    (org-refile nil nil (list (file-name-nondirectory (buffer-file-name))
                              (buffer-file-name) nil nil))))
(with-eval-after-load 'org
  (define-key org-mode-map (kbd "C-c t") #'my/org-subtree-to-top))
```

How it works:

- Capture: `C-c c n`, type the idea, `C-c C-c`. The entry goes above the first heading. [OM:Template-elements], [src:org-capture.el:1327-1330]
- Rescue: put point on a heading, `C-c t`. The helper passes an RFLOC with no position to `org-refile`. The `org-refile` docstring documents RFLOC as a 4-element list (name, file, nil, position). [src:org-refile.el:462-472] With `org-reverse-note-order` set to t, Org pastes the subtree at level 1 above the first heading. [src:org-refile.el:584-591]
- The helper needs a buffer that visits a file. A child heading becomes level 1 when you move it.
- `org-keys.el` does not bind `C-c t`. [src:org-keys.el] Emacs reserves `C-c` plus a letter for users. Unverified (the key binding conventions node was not fetched). Other packages can still use the key. Choose another key if it conflicts.

**Tested: yes.** I ran `emacs -Q --batch` with Emacs 31.1.50 and Org 9.8.7 on a temp file. The test used the same template plus `:immediate-finish t` (batch mode cannot type input). Start file:

```org
#+TITLE: notes

* old A
body A
* old B
** child B1
* old C
```

Steps: capture "new idea", move "old B" to top, move "child B1" to top. Result:

```org
#+TITLE: notes
* child B1
* old B
* new idea
* old A
body A
* old C
```

The `#+TITLE` line stayed first. The blank line after it was lost during the test. I did not check which step removed it. I did not test the interactive `C-c C-M-w` path; its behavior comes from reading the source.

## 4. Trade-offs vs Apple Notes

- **Sync and phone.** Apple Notes syncs and backs up by itself. [K] Org has no built-in sync. You need a file sync tool and a phone app, or Org Mobile. [OM:Org-Mobile] Phone editing quality depends on third-party apps. Unverified.
- **Structure.** Apple Notes is free text. Org capture `entry` makes each item a heading. Headings make move, fold, archive, and refile work. [OM:Structure-Editing] Free text between headings has no subtree commands. A `plain` template keeps free text but loses the subtree helpers. [OM:Template-elements]
- **Flat file.** Use `(file ...)`, not `(file+headline ...)`, to keep one flat list like Karpathy. [OM:Template-elements]
- **Rescue cost.** In Apple Notes, rescue is copy and paste. [K] In Org, it is one key with the helper, and the text keeps its body and children.
- **Search.** CTRL+F maps to `C-s`. `org-occur` adds a folded view of all matches, which Apple Notes does not have. Unverified for Apple Notes.
- **Metadata.** Karpathy avoids dates. [K] Org makes `%U` easy, but the template above leaves it out to match the method.
