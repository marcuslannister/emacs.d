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

(ert-deftest init-local-tui-setup-turns-on-osc-52-copy ()
  (let ((xterm-extra-capabilities 'check)
        (load-path load-path))
    (cl-letf (((symbol-function 'locate-user-emacs-file)
               (lambda (&rest _) temporary-file-directory))
              ((symbol-function 'require) #'ignore)
              ((symbol-function 'my/hel-setup) #'ignore))
      (my/tui-setup))
    (should (equal xterm-extra-capabilities '(setSelection)))))

(ert-deftest init-local-tui-setup-loads-the-theme-after-hel ()
  (let ((calls nil)
        (load-path load-path))
    (cl-letf (((symbol-function 'locate-user-emacs-file)
               (lambda (&rest _) temporary-file-directory))
              ((symbol-function 'require) (lambda (feature &rest _) (push feature calls)))
              ((symbol-function 'my/hel-setup) (lambda () (push 'hel-setup calls))))
      (my/tui-setup))
    (should (equal (nreverse calls) '(init-local-hel hel-setup init-local-themes)))))

(provide 'init-local-tui-tests)
;;; init-local-tui-tests.el ends here
