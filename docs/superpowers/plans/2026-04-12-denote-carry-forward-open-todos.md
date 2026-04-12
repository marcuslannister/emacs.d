# Denote Carry-Forward Open Todos Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a separate Denote journal command that creates or opens a journal note and carries unfinished Markdown checkbox items from the most recent earlier journal entry into a single idempotent carry-forward section.

**Architecture:** Keep the change local to `lisp/init-local-denote.el` by adding small helpers for prior-journal resolution, Markdown checkbox extraction, idempotent insertion, and shared timestamp insertion. Add focused ERT coverage in a new `tests/` file for the pure helpers, then keep the repo-level startup check as the integration verification.

**Tech Stack:** Emacs Lisp, `denote`, `denote-journal`, ERT, shell startup smoke test

---

## File Structure

- Modify: `lisp/init-local-denote.el`
  Responsibility: add the new interactive command and helper functions for journal lookup, checkbox extraction, carry-forward insertion, and shared timestamp insertion.
- Modify: `lisp/init-local-keybinding.el`
  Responsibility: expose the new command on a local keybinding without replacing the existing journal command.
- Create: `tests/init-local-denote-tests.el`
  Responsibility: verify prior-journal selection, checkbox extraction, and idempotent insertion behavior with isolated ERT tests.

### Task 1: Add helper tests for prior journal lookup

**Files:**
- Create: `tests/init-local-denote-tests.el`
- Modify: `lisp/init-local-denote.el`

- [ ] **Step 1: Write the failing test**

```elisp
(ert-deftest init-local-denote-find-latest-prior-journal-across-year-boundary ()
  (let ((files '("/tmp/20241230T090000--old__journal.md"
                 "/tmp/20250107T090000--prev__journal.md"
                 "/tmp/20250108T090000--today__journal.md")))
    (should
     (equal
      (my/denote-journal-latest-prior-file
       "2025-01-08"
       files)
      "/tmp/20250107T090000--prev__journal.md"))))
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
emacs -Q --batch -L . -l tests/init-local-denote-tests.el -f ert-run-tests-batch-and-exit
```

Expected: `FAIL` because `my/denote-journal-latest-prior-file` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```elisp
(defun my/denote-journal-latest-prior-file (target-date files)
  ;; Parse Denote identifier dates from FILES and return the latest one before TARGET-DATE.
  ...)
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
emacs -Q --batch -L . -l tests/init-local-denote-tests.el -f ert-run-tests-batch-and-exit
```

Expected: the new lookup test passes.

- [ ] **Step 5: Commit**

```bash
jj commit -m "test: cover denote prior journal lookup"
```

### Task 2: Add helper tests for unfinished Markdown checkbox extraction

**Files:**
- Modify: `tests/init-local-denote-tests.el`
- Modify: `lisp/init-local-denote.el`

- [ ] **Step 1: Write the failing test**

```elisp
(ert-deftest init-local-denote-read-open-checkbox-lines ()
  (let ((file (make-temp-file "denote-checkbox" nil ".md"
                              "- [ ] keep me\n- [x] done\n* [ ] keep me too\n")))
    (unwind-protect
        (should
         (equal
          (my/denote-journal-open-checkbox-lines file)
          '("- [ ] keep me" "* [ ] keep me too")))
      (delete-file file))))
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
emacs -Q --batch -L . -l tests/init-local-denote-tests.el -f ert-run-tests-batch-and-exit
```

Expected: `FAIL` because `my/denote-journal-open-checkbox-lines` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```elisp
(defun my/denote-journal-open-checkbox-lines (file)
  ;; Return unfinished Markdown checkbox lines from FILE.
  ...)
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
emacs -Q --batch -L . -l tests/init-local-denote-tests.el -f ert-run-tests-batch-and-exit
```

Expected: both lookup and checkbox tests pass.

- [ ] **Step 5: Commit**

```bash
jj commit -m "test: cover denote carry-forward checkbox parsing"
```

### Task 3: Add helper tests for idempotent carry-forward insertion

**Files:**
- Modify: `tests/init-local-denote-tests.el`
- Modify: `lisp/init-local-denote.el`

- [ ] **Step 1: Write the failing test**

```elisp
(ert-deftest init-local-denote-insert-carry-forward-block-once ()
  (with-temp-buffer
    (insert "# 09:00 #\n")
    (my/denote-journal-insert-carry-forward-section
     '("- [ ] keep me"))
    (my/denote-journal-insert-carry-forward-section
     '("- [ ] keep me"))
    (goto-char (point-min))
    (should (= (how-many "^## Carried Forward$" (point-min) (point-max)) 1))))
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
emacs -Q --batch -L . -l tests/init-local-denote-tests.el -f ert-run-tests-batch-and-exit
```

Expected: `FAIL` because `my/denote-journal-insert-carry-forward-section` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```elisp
(defun my/denote-journal-insert-carry-forward-section (items)
  ;; Insert a single carry-forward block when ITEMS are present and the heading is absent.
  ...)
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
emacs -Q --batch -L . -l tests/init-local-denote-tests.el -f ert-run-tests-batch-and-exit
```

Expected: all helper tests pass.

- [ ] **Step 5: Commit**

```bash
jj commit -m "test: cover denote carry-forward insertion"
```

### Task 4: Implement the interactive command and shared timestamp behavior

**Files:**
- Modify: `lisp/init-local-denote.el`
- Modify: `tests/init-local-denote-tests.el`

- [ ] **Step 1: Write the failing test**

```elisp
(ert-deftest init-local-denote-new-entry-with-open-todos-carries-forward-when-source-exists ()
  ;; Stub journal file discovery and entry opening, then verify the target buffer
  ;; receives a single carry-forward block and timestamp section.
  ...)
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
emacs -Q --batch -L . -l tests/init-local-denote-tests.el -f ert-run-tests-batch-and-exit
```

Expected: `FAIL` because the new command does not yet perform carry-forward.

- [ ] **Step 3: Write minimal implementation**

```elisp
(defun my/denote-journal-new-entry-with-open-todos (&optional date)
  (interactive
   (list
    (when current-prefix-arg
      (denote-date-prompt))))
  ...)
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
emacs -Q --batch -L . -l tests/init-local-denote-tests.el -f ert-run-tests-batch-and-exit
```

Expected: the command-level regression and all helper tests pass.

- [ ] **Step 5: Commit**

```bash
jj commit -m "feat: add denote journal carry-forward command"
```

### Task 5: Expose the command and verify startup

**Files:**
- Modify: `lisp/init-local-keybinding.el`
- Test: `test-startup.sh`

- [ ] **Step 1: Write the failing test**

```elisp
(ert-deftest init-local-denote-command-is-bound-in-keybindings ()
  ;; Optional focused load test if keybinding coverage is practical.
  ...)
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
emacs -Q --batch -L . -l tests/init-local-denote-tests.el -f ert-run-tests-batch-and-exit
```

Expected: `FAIL` if a focused keybinding test is added; otherwise treat the startup check as the verification gate for this task.

- [ ] **Step 3: Write minimal implementation**

```elisp
(kbd "<leader> jt") '("Create entry with open todos" . my/denote-journal-new-entry-with-open-todos)
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
emacs -Q --batch -L . -l tests/init-local-denote-tests.el -f ert-run-tests-batch-and-exit
./test-startup.sh
```

Expected: ERT tests pass and startup finishes with `Startup successful`.

- [ ] **Step 5: Commit**

```bash
jj commit -m "feat: bind denote carry-forward journal command"
```
