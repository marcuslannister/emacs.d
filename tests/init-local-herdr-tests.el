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

(ert-deftest init-local-herdr-tab-mate-pane ()
  (let ((snap '((panes . (((pane_id . "w:p1") (tab_id . "w:t1") (focused . t))
                          ((pane_id . "w:p2") (tab_id . "w:t1") (focused . :false))))
                (agents . (((pane_id . "w:p2") (tab_id . "w:t1"))
                           ((pane_id . "w:p9") (tab_id . "w:t2")))))))
    ;; One agent beside the focused terminal pane: use it.
    (should (equal (ml/herdr--tab-mate-pane snap) "w:p2"))
    ;; Two agents in the tab: ambiguous, so let the user pick.
    (push '((pane_id . "w:p3") (tab_id . "w:t1")) (alist-get 'agents snap))
    (should-not (ml/herdr--tab-mate-pane snap))
    ;; Focused pane is an agent beside another agent: do not guess.
    (should-not (ml/herdr--tab-mate-pane
                 '((panes . (((pane_id . "w:p1") (tab_id . "w:t1") (focused . t)
                              (agent . "claude"))))
                   (agents . (((pane_id . "w:p1") (tab_id . "w:t1"))
                              ((pane_id . "w:p2") (tab_id . "w:t1")))))))
    ;; No focused pane: nothing to compare against.
    (should-not (ml/herdr--tab-mate-pane '((panes . (((pane_id . "w:p1") (tab_id . "w:t1"))))
                                           (agents . (((pane_id . "w:p2") (tab_id . "w:t1")))))))))

(ert-deftest init-local-herdr-copy-advice-replaces-kill ()
  (init-local-herdr-tests--with-screen init-local-herdr-tests--screen
    (goto-char (point-min))
    (search-forward "Ran")
    (let ((transient-mark-mode t)
          (kill-ring nil)
          (interprogram-cut-function nil))
      (set-mark (- (point) 3))
      (end-of-line)
      (activate-mark)
      (ml/herdr--copy-pane-region
       (lambda () (kill-ring-save (region-beginning) (region-end))))
      (should (equal kill-ring '("Ran 1 shell command"))))))

(ert-deftest init-local-herdr-copy-advice-skips-other-ghostel ()
  ;; Ghostel's own copy joins soft-wrapped lines; the advice must keep it.
  (with-temp-buffer
    (rename-buffer "*ghostel*" t)
    (ghostel-mode)
    (insert "long-com\nmand   ")
    (let ((transient-mark-mode t)
          (kill-ring nil)
          (interprogram-cut-function nil))
      (set-mark (point-min))
      (goto-char (point-max))
      (activate-mark)
      (ml/herdr--copy-pane-region (lambda () (kill-new "long-command")))
      (should (equal kill-ring '("long-command"))))))

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
