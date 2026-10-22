;;; init-local-herdr-tests.el --- Herdr raw-send text tests -*- lexical-binding: t; -*-
;;; Commentary:
;; Run: emacs -Q --batch -l tests/init-local-herdr-tests.el -f ert-run-tests-batch-and-exit
;;; Code:

(require 'cl-lib)
(require 'ert)

(let ((root (file-name-directory
             (directory-file-name (file-name-directory (or load-file-name buffer-file-name))))))
  ;; No herdr binary: load only the helper, not the use-package form.
  (cl-letf (((symbol-function 'executable-find) #'ignore))
    (load (expand-file-name "lisp/init-local-herdr.el" root) nil t)))

(unless (fboundp 'ghostel-mode)
  (define-derived-mode ghostel-mode fundamental-mode "Ghostel"))

(defconst init-local-herdr-tests--screen
  (concat "   main            │⏺ The test failed   │ other pane\n"
          " ○ emacs.d         │                    │\n"
          "   main            │  Ran 1 shell command│ x\n"))

(defmacro init-local-herdr-tests--with-screen (text &rest body)
  "Run BODY in a *herdr* Ghostel buffer that holds TEXT."
  (declare (indent 1))
  `(with-temp-buffer
     (rename-buffer "*herdr*" t)
     (insert ,text)
     (ghostel-mode)
     ,@body))

(ert-deftest init-local-herdr-pane-line-at-point ()
  (init-local-herdr-tests--with-screen init-local-herdr-tests--screen
    (goto-char (point-min))
    (search-forward "Ran")
    (should (equal (string-trim (ml/herdr--pane-text (line-beginning-position)
                                                     (line-end-position)))
                   "Ran 1 shell command"))))

(ert-deftest init-local-herdr-pane-region-multi-line ()
  (init-local-herdr-tests--with-screen init-local-herdr-tests--screen
    (goto-char (point-min))
    (search-forward "⏺")
    (let ((beg (1- (point))))
      (search-forward "command")
      (set-mark beg)
      (activate-mark)
      (let ((transient-mark-mode t))
        (should (equal (ml/herdr--pane-text beg (point))
                       "⏺ The test failed\n\n  Ran 1 shell command"))))))

(ert-deftest init-local-herdr-pane-right-pane-drops-scrollbar ()
  (init-local-herdr-tests--with-screen " ○ emacs.d  ││❯ left text     ││right text here      ▕│\n"
    (goto-char (point-min))
    (search-forward "right")
    (should (equal (ml/herdr--pane-text (line-beginning-position) (line-end-position))
                   "right text here"))))

(ert-deftest init-local-herdr-pane-wide-char-drift ()
  ;; Line 2 has a wide char, so its borders sit one column left of line 1's.
  (init-local-herdr-tests--with-screen (concat " side  ││left pane    ││right one    ▕│\n"
                                               " side  ││✽ left 中   ││zsh: right two▐│\n")
    (goto-char (point-min))
    (search-forward "right")
    (should (equal (ml/herdr--pane-text (line-beginning-position) (point-max))
                   "right one\nzsh: right two"))))

(ert-deftest init-local-herdr-pane-trims-nbsp-prompt ()
  (init-local-herdr-tests--with-screen " side  ││❯\u00a0           ▕│\n"
    (goto-char (point-min))
    (search-forward "❯")
    (should (equal (ml/herdr--pane-text (line-beginning-position) (line-end-position))
                   "❯"))))

(ert-deftest init-local-herdr-line-drops-claude-marker ()
  (init-local-herdr-tests--with-screen (concat " side  ││❯\u00a0! cat AGENTS.md     ▕│\n"
                                               " side  ││⏺ Ran 1 shell command  ▕│\n")
    (goto-char (point-min))
    (search-forward "cat")
    (should (equal (ml/herdr--text-at-point) "! cat AGENTS.md"))
    (forward-line 1)
    (search-forward "Ran")
    (should (equal (ml/herdr--text-at-point) "Ran 1 shell command"))))

(defun init-local-herdr-tests--snap (focused &rest agents)
  "Snapshot of tab w:t1: FOCUSED pane alist, then AGENTS as (PANE . TAB)."
  `((panes . (,focused))
    (agents . ,(mapcar (lambda (a) `((pane_id . ,(car a)) (tab_id . ,(cdr a)))) agents))))

(ert-deftest init-local-herdr-target-pane ()
  (let ((term '((pane_id . "w:p1") (tab_id . "w:t1") (focused . t)))
        (claude '((pane_id . "w:p1") (tab_id . "w:t1") (focused . t) (agent . "claude"))))
    ;; Focused terminal, one agent in its tab: send there.
    (should (equal (ml/herdr--target-pane
                    (init-local-herdr-tests--snap term '("w:p2" . "w:t1") '("w:p9" . "w:t2")))
                   "w:p2"))
    ;; Focused terminal, two agents in its tab: ambiguous, so the user picks.
    (should-not (ml/herdr--target-pane
                 (init-local-herdr-tests--snap term '("w:p2" . "w:t1") '("w:p3" . "w:t1"))))
    ;; Focused Claude pane, even beside another agent: send to itself.
    (should (equal (ml/herdr--target-pane
                    (init-local-herdr-tests--snap claude '("w:p1" . "w:t1") '("w:p2" . "w:t1")))
                   "w:p1"))
    ;; No focused pane: the user picks.
    (should-not (ml/herdr--target-pane
                 (init-local-herdr-tests--snap (assq-delete-all 'focused (copy-alist term))
                                               '("w:p2" . "w:t1"))))))

(ert-deftest init-local-herdr-copy-filter-cuts-every-copy ()
  ;; The filter serves kill-ring-save, copy mode RET and M-w, and a mouse
  ;; drag; none of them needs an active region.
  (init-local-herdr-tests--with-screen init-local-herdr-tests--screen
    (let ((kill-ring nil)
          (interprogram-cut-function nil))
      (goto-char (point-min))
      (search-forward "⏺")
      (let ((beg (1- (point))))
        (search-forward "command")
        (copy-region-as-kill beg (point)))
      (goto-char (point-min))
      (should (equal kill-ring '("⏺ The test failed\n\n  Ran 1 shell command"))))))

(ert-deftest init-local-herdr-highlight-stays-in-pane ()
  (init-local-herdr-tests--with-screen init-local-herdr-tests--screen
    (should (eq redisplay-highlight-region-function #'ml/herdr--highlight-region))
    (goto-char (point-min))
    (search-forward "⏺")
    (let* ((beg (1- (point)))
           (end (progn (search-forward "command") (point)))
           (rol (ml/herdr--highlight-region beg end (selected-window) nil))
           (shown (mapcar (lambda (ov)
                            (buffer-substring-no-properties (overlay-start ov) (overlay-end ov)))
                          (cdr rol))))
      ;; One overlay per line, each inside the middle pane: no sidebar, no x pane.
      (should (eq (car rol) 'ml/herdr))
      (should (equal (mapcar #'string-trim-right shown)
                     '("⏺ The test failed" "" "  Ran 1 shell command")))
      (funcall redisplay-unhighlight-region-function rol)
      (should-not (seq-some #'overlay-buffer (cdr rol))))))

(ert-deftest init-local-herdr-copy-filter-skips-other-ghostel ()
  ;; Other Ghostel buffers keep Ghostel's own copy (it joins soft wraps).
  (with-temp-buffer
    (rename-buffer "*ghostel*" t)
    (insert "a │ b")
    (ghostel-mode)
    (let ((kill-ring nil)
          (interprogram-cut-function nil))
      (copy-region-as-kill (point-min) (point-max))
      (should (equal kill-ring '("a │ b"))))))

(ert-deftest init-local-herdr-pane-other-ghostel-unchanged ()
  (with-temp-buffer
    (rename-buffer "*ghostel*" t)
    (ghostel-mode)
    (insert "a │ b")
    (should (equal (ml/herdr--pane-text (point-min) (point-max)) "a │ b"))))

(ert-deftest init-local-herdr-pane-non-ghostel-unchanged ()
  (with-temp-buffer
    (insert "a │ b")
    (should (equal (ml/herdr--pane-text (point-min) (point-max)) "a │ b"))))

(provide 'init-local-herdr-tests)
;;; init-local-herdr-tests.el ends here
