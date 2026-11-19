;;; init-local-translate-tests.el --- Tests for init-local-translate -*- lexical-binding: t -*-
;;; Commentary:
;; Run: emacs -Q --batch -l tests/init-local-translate-tests.el -f ert-run-tests-batch-and-exit
;; The gt package is not loaded: the tests only check the autoload and the key.
;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'use-package)
(require 'warnings) ; `display-warning' starts as an autoload, and a stub would not stay.
;; -Q uses ~/.emacs.d: never install there.
(setq use-package-ensure-function #'ignore use-package-always-defer t)

(defvar init-local-translate-tests--keys nil
  "The (KEY . COMMAND) pairs that the module binds.")

(defun my/hel-leader-bind (&rest args)
  "Record the KEY COMMAND pairs in ARGS."
  (while args
    (push (cons (pop args) (pop args)) init-local-translate-tests--keys)))

(load (expand-file-name "../user-lisp/init-local-translate.el"
                        (file-name-directory (or load-file-name buffer-file-name)))
      nil t)

(ert-deftest init-local-translate-setup-warns-when-sdcv-is-missing ()
  (let (warnings (init-local-translate-tests--keys nil))
    (cl-letf (((symbol-function 'executable-find) (lambda (&rest _) nil))
              ((symbol-function 'display-warning)
               (lambda (type msg &rest _) (push (cons type msg) warnings))))
      (my/translate-setup))
    (should (= 1 (length warnings)))
    (should (eq 'init-local-translate (car (car warnings))))
    (should-not init-local-translate-tests--keys)))

(ert-deftest init-local-translate-setup-binds-g-t-to-translate ()
  (let ((init-local-translate-tests--keys nil))
    (unwind-protect
        (cl-letf (((symbol-function 'executable-find) (lambda (&rest _) "/x/sdcv")))
          (my/translate-setup)
          (should (autoloadp (symbol-function 'gt-translate)))
          (should (equal '(("C-c g t" . gt-translate))
                         init-local-translate-tests--keys)))
      (fmakunbound 'gt-translate))))

(provide 'init-local-translate-tests)
;;; init-local-translate-tests.el ends here
