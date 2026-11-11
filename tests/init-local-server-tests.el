;;; init-local-server-tests.el --- Emacs server tests -*- lexical-binding: t; -*-
;;; Commentary:
;; Run: emacs -Q --batch -l tests/init-local-server-tests.el -f ert-run-tests-batch-and-exit
;;; Code:

(require 'ert)
(require 'cl-lib)
;; These start as autoloads; load them before any test stubs them.
(require 'warnings)
(require 'server)

(load-file (expand-file-name "../user-lisp/init-local-server.el"
                             (file-name-directory (or load-file-name buffer-file-name))))

(defun init-local-server-tests--run (&rest options)
  "Run `my/server-start' with stubs; return a plist of what happened.
`:batch' makes Emacs non-interactive.  `:running' makes a server of that name
look alive.  The result has the `server-name' at each start and the warnings."
  (let ((started nil)
        (warnings nil)
        (saved-name server-name))
    (unwind-protect
        (let ((noninteractive (plist-get options :batch)))
          (cl-letf (((symbol-function 'server-running-p)
                     (lambda (&rest _) (plist-get options :running)))
                    ((symbol-function 'server-start)
                     (lambda (&rest _) (push server-name started)))
                    ((symbol-function 'display-warning)
                     (lambda (type message &rest _) (push (cons type message) warnings))))
            (my/server-start)))
      (setq server-name saved-name))
    (list :started started :warnings (nreverse warnings))))

(ert-deftest init-local-server-default-name-is-nn-except-on-windows ()
  (let ((form (car (get 'my/server-name 'standard-value))))
    (dolist (pair '((darwin . "nn") (gnu/linux . "nn") (windows-nt . "server")))
      (let ((system-type (car pair)))
        (should (equal (cdr pair) (eval form)))))))

(ert-deftest init-local-server-starts-under-the-configured-name ()
  (let* ((my/server-name "nn")
         (result (init-local-server-tests--run)))
    (should (equal '("nn") (plist-get result :started)))
    (should-not (plist-get result :warnings)))
  (let* ((my/server-name "server")
         (result (init-local-server-tests--run)))
    (should (equal '("server") (plist-get result :started)))))

(ert-deftest init-local-server-does-nothing-in-batch ()
  (let ((result (init-local-server-tests--run :batch t)))
    (should-not (plist-get result :started))
    (should-not (plist-get result :warnings))))

(ert-deftest init-local-server-warns-when-the-name-is-taken ()
  (let* ((my/server-name "nn")
         (result (init-local-server-tests--run :running t))
         (warnings (plist-get result :warnings)))
    (should-not (plist-get result :started))
    (should (= 1 (length warnings)))
    (should (eq 'init-local-server (car (car warnings))))
    (should (string-match-p "named nn already runs" (cdr (car warnings))))))

(provide 'init-local-server-tests)
;;; init-local-server-tests.el ends here
