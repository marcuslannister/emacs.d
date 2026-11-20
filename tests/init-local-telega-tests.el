;;; init-local-telega-tests.el --- Telega module tests -*- lexical-binding: t; -*-
;;; Commentary:
;; Run: emacs -Q --batch -l tests/init-local-telega-tests.el -f ert-run-tests-batch-and-exit
;; Telega is not loaded: the tests stub what the module calls.
;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'use-package)

(defvar nn-proxy-port 7897)
(defvar telega-before-auth-hook)

(defconst init-local-telega-tests--module
  (expand-file-name "../user-lisp/init-local-telega.el"
                    (file-name-directory (or load-file-name buffer-file-name)))
  "The module under test.")

(defun init-local-telega-tests--load (system)
  "Load the module as if `system-type' were SYSTEM, with no install."
  (let ((system-type system)
        (use-package-always-defer t)
        (use-package-always-ensure nil)
        (use-package-ensure-function #'ignore))
    (load init-local-telega-tests--module nil t)))

(ert-deftest init-local-telega-sets-no-hook-off-macos ()
  (dolist (system '(windows-nt gnu/linux))
    (makunbound 'telega-before-auth-hook)
    (init-local-telega-tests--load system)
    (should-not (bound-and-true-p telega-before-auth-hook))))

(ert-deftest init-local-telega-sets-the-proxy-hook-on-macos ()
  (makunbound 'telega-before-auth-hook)
  (init-local-telega-tests--load 'darwin)
  (should (memq 'my/telega-proxy telega-before-auth-hook)))

(ert-deftest init-local-telega-proxy-is-socks5-on-the-base-port ()
  (init-local-telega-tests--load 'darwin)
  (let (args)
    (cl-letf (((symbol-function 'telega--addProxy) (lambda (&rest a) (setq args a))))
      (my/telega-proxy))
    (should (equal '(:server "localhost" :port 7897 :type (:@type "proxyTypeSocks5"))
                   (car args)))
    (should (eq 'enable (plist-get (cdr args) :enable-p)))))

(provide 'init-local-telega-tests)
;;; init-local-telega-tests.el ends here
