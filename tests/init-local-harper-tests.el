;;; init-local-harper-tests.el --- Harper module tests -*- lexical-binding: t -*-
;;; Commentary:
;; Run in batch Emacs.  Eglot calls are stubbed; no language server starts.
;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'eglot)

(defvar my/harper-test-bindings nil)
(defun my/hel-leader-bind (&rest args)
  (while args
    (push (cons (pop args) (pop args)) my/harper-test-bindings)))

(load-file (expand-file-name "../user-lisp/init-local-harper.el"
                             (file-name-directory (or load-file-name buffer-file-name))))

(ert-deftest init-local-harper-binds-spc-e-g ()
  (should (eq (cdr (assoc "C-c e g g" my/harper-test-bindings)) #'my/harper-toggle))
  (should (eq (cdr (assoc "C-c e g a" my/harper-test-bindings)) #'eglot-code-actions)))

(ert-deftest init-local-harper-registers-prose-modes ()
  (let ((eglot-server-programs nil)
        (eglot-workspace-configuration nil))
    (cl-letf (((symbol-function 'executable-find) (lambda (_) "/bin/harper-ls")))
      (my/harper-setup))
    (should (equal (car eglot-server-programs)
                   '((org-mode markdown-ts-mode text-mode) "harper-ls" "--stdio")))
    (should (equal (plist-get (plist-get eglot-workspace-configuration :harper-ls) :dialect)
                   "American"))))

(ert-deftest init-local-harper-toggle-starts-then-stops ()
  (let (calls server)
    (cl-letf (((symbol-function 'eglot-current-server) (lambda () server))
              ((symbol-function 'eglot) (lambda (&rest _) (interactive) (push 'start calls)))
              ((symbol-function 'eglot-shutdown) (lambda (_) (push 'stop calls))))
      (with-temp-buffer
        (text-mode)
        (my/harper-toggle)
        (setq server 'harper)
        (my/harper-toggle)))
    (should (equal (nreverse calls) '(start stop)))))

(ert-deftest init-local-harper-toggle-refuses-code-buffers ()
  (with-temp-buffer
    (emacs-lisp-mode)
    (should-error (my/harper-toggle) :type 'user-error)))

;;; init-local-harper-tests.el ends here
