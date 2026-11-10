;;; init-local-exec-path-tests.el --- PATH import tests -*- lexical-binding: t; -*-
;;; Commentary:
;; Run: emacs -Q --batch -l tests/init-local-exec-path-tests.el -f ert-run-tests-batch-and-exit
;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'use-package)

(defconst init-local-exec-path-tests--file
  (expand-file-name "../user-lisp/init-local-exec-path.el"
                    (file-name-directory (or load-file-name buffer-file-name)))
  "The module under test.")

(defun init-local-exec-path-tests--run (system &rest options)
  "Load the module as on SYSTEM; return a plist with the warnings and import count.
OPTIONS is a plist.  `:gui' is non-nil for a graphical session.  `:package' is
non-nil when exec-path-from-shell is installed.  `:fail' makes the import
signal an error."
  (let ((warnings nil)
        (imports 0)
        (system-type system)
        (use-package-always-defer t)
        (use-package-always-ensure nil)
        (saved-features features)
        (saved-load-path load-path))
    ;; Set these two with `setq': a `let' binding of `features' has no effect
    ;; under lexical binding in Emacs 31.
    (unwind-protect
        (progn
          (setq features (if (plist-get options :package)
                             (cons 'exec-path-from-shell
                                   (remq 'exec-path-from-shell features))
                           (remq 'exec-path-from-shell features))
                load-path (if (plist-get options :package) load-path nil))
          (cl-letf (((symbol-function 'display-graphic-p)
                     (lambda (&rest _) (plist-get options :gui)))
                    ((symbol-function 'display-warning)
                     (lambda (type message &rest _) (push (cons type message) warnings)))
                    ((symbol-function 'exec-path-from-shell-initialize)
                     (lambda ()
                       (setq imports (1+ imports))
                       (when (plist-get options :fail) (error "boom")))))
            (load init-local-exec-path-tests--file nil t)))
      (setq features saved-features
            load-path saved-load-path))
    (list :warnings (nreverse warnings) :imports imports)))

(ert-deftest init-local-exec-path-does-nothing-outside-macos ()
  (let ((result (init-local-exec-path-tests--run 'windows-nt :gui t :package t)))
    (should (= 0 (plist-get result :imports)))
    (should-not (plist-get result :warnings))))

(ert-deftest init-local-exec-path-skips-a-terminal-session ()
  (let ((result (init-local-exec-path-tests--run 'darwin :gui nil :package t)))
    (should (= 0 (plist-get result :imports)))
    (should-not (plist-get result :warnings))))

(ert-deftest init-local-exec-path-imports-once-in-a-gui-session ()
  (let ((result (init-local-exec-path-tests--run 'darwin :gui t :package t)))
    (should (= 1 (plist-get result :imports)))
    (should-not (plist-get result :warnings))))

(ert-deftest init-local-exec-path-warns-when-the-package-is-missing ()
  (let* ((result (init-local-exec-path-tests--run 'darwin :gui t :package nil))
         (warnings (plist-get result :warnings)))
    (should (= 0 (plist-get result :imports)))
    (should (= 1 (length warnings)))
    (should (eq 'init-local-exec-path (car (car warnings))))
    (should (string-match-p "not installed" (cdr (car warnings))))))

(ert-deftest init-local-exec-path-warns-when-the-import-fails ()
  (let* ((result (init-local-exec-path-tests--run 'darwin :gui t :package t :fail t))
         (warnings (plist-get result :warnings)))
    (should (= 1 (plist-get result :imports)))
    (should (= 1 (length warnings)))
    (should (string-match-p "PATH import skipped: boom" (cdr (car warnings))))))

(provide 'init-local-exec-path-tests)
;;; init-local-exec-path-tests.el ends here
