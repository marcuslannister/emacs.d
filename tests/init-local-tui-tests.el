;;; init-local-tui-tests.el --- Terminal-only session tests -*- lexical-binding: t; -*-
;;; Commentary:
;; Run: emacs -Q --batch -l tests/init-local-tui-tests.el -f ert-run-tests-batch-and-exit
;;; Code:

(require 'ert)
(require 'cl-lib)

(load-file (expand-file-name "../user-lisp/init-local-tui.el"
                             (file-name-directory (or load-file-name buffer-file-name))))

(defun init-local-tui-tests--p (batch daemon graphic)
  "Return `my/tui-session-p' with BATCH, DAEMON, and GRAPHIC stubbed."
  (let ((noninteractive batch))
    (cl-letf (((symbol-function 'daemonp) (lambda () daemon))
              ((symbol-function 'display-graphic-p) (lambda (&rest _) graphic)))
      (my/tui-session-p))))

(ert-deftest init-local-tui-only-an-interactive-terminal-is-a-tui-session ()
  (should (init-local-tui-tests--p nil nil nil))
  (should-not (init-local-tui-tests--p t nil nil))
  (should-not (init-local-tui-tests--p nil t nil))
  (should-not (init-local-tui-tests--p nil nil t)))

(defvar xterm-extra-capabilities)
(defvar markdown-ts-mode-hook)

(defmacro init-local-tui-tests--with-setup (grammar &rest body)
  "Run `my/tui-setup' with GRAMMAR as the tree-sitter answer, then run BODY.
In BODY, `calls' lists, in order, the Local modules it required and the Hel setup."
  (declare (indent 1))
  `(let ((calls nil)
         (orig (symbol-function 'require))
         (xterm-extra-capabilities 'check)
         (load-path load-path)
         (auto-mode-alist auto-mode-alist)
         (markdown-ts-mode-hook nil))
     (cl-letf (((symbol-function 'require)
                (lambda (feature &rest args)
                  (if (memq feature '(init-local-hel init-local-themes))
                      (push feature calls)
                    (apply orig feature args))))
               ((symbol-function 'locate-user-emacs-file)
                (lambda (&rest _) temporary-file-directory))
               ((symbol-function 'my/hel-setup) (lambda () (push 'hel-setup calls)))
               ((symbol-function 'treesit-language-available-p) (lambda (&rest _) ,grammar)))
       (my/tui-setup))
     (setq calls (nreverse calls))
     ,@body))

(ert-deftest init-local-tui-setup-turns-on-osc-52-copy ()
  (init-local-tui-tests--with-setup t
    (should (equal xterm-extra-capabilities '(setSelection)))))

(ert-deftest init-local-tui-setup-loads-the-theme-after-hel ()
  (init-local-tui-tests--with-setup t
    (should (equal calls '(init-local-hel hel-setup init-local-themes)))))

(ert-deftest init-local-tui-setup-registers-markdown-only-with-its-grammar ()
  (init-local-tui-tests--with-setup t
    (should (eq (cdr (assoc "\\.md\\'" auto-mode-alist)) 'markdown-ts-mode)))
  (init-local-tui-tests--with-setup nil
    (should-not (eq (cdr (assoc "\\.md\\'" auto-mode-alist)) 'markdown-ts-mode))))

(provide 'init-local-tui-tests)
;;; init-local-tui-tests.el ends here
