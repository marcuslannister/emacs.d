;;; init-local-zoxide-tests.el --- Tests for init-local-zoxide -*- lexical-binding: t -*-
;;; Commentary:
;; Run: emacs -Q --batch -l tests/init-local-zoxide-tests.el -f ert-run-tests-batch-and-exit
;; The zoxide package is not loaded: the tests only check the autoload and the key.
;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'use-package)
(require 'warnings) ; `display-warning' starts as an autoload, and a stub would not stay.
;; -Q uses ~/.emacs.d: never install there.
(setq use-package-ensure-function #'ignore use-package-always-defer t)

(defvar init-local-zoxide-tests--keys nil "The (KEY . COMMAND) pairs that the module binds.")

(defun my/hel-leader-bind (&rest args)
  "Record the KEY COMMAND pairs in ARGS."
  (while args
    (push (cons (pop args) (pop args)) init-local-zoxide-tests--keys)))

(load (expand-file-name "../user-lisp/init-local-zoxide.el"
                        (file-name-directory (or load-file-name buffer-file-name)))
      nil t)

(ert-deftest init-local-zoxide-setup-warns-when-the-program-is-missing ()
  (let (warnings (init-local-zoxide-tests--keys nil))
    (cl-letf (((symbol-function 'executable-find) (lambda (&rest _) nil))
              ((symbol-function 'display-warning)
               (lambda (type msg &rest _) (push (cons type msg) warnings))))
      (my/zoxide-setup))
    (should (= 1 (length warnings)))
    (should (eq 'init-local-zoxide (car (car warnings))))
    (should-not init-local-zoxide-tests--keys)))

(ert-deftest init-local-zoxide-setup-binds-z-t-to-travel ()
  (let ((init-local-zoxide-tests--keys nil))
    (unwind-protect
        (cl-letf (((symbol-function 'executable-find) (lambda (&rest _) "/x/zoxide")))
          (my/zoxide-setup)
          (should (autoloadp (symbol-function 'zoxide-travel)))
          (should (equal '(("C-c z t" . zoxide-travel)) init-local-zoxide-tests--keys)))
      (fmakunbound 'zoxide-travel))))

(provide 'init-local-zoxide-tests)
;;; init-local-zoxide-tests.el ends here
