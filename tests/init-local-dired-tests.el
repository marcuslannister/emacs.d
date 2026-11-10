;;; init-local-dired-tests.el --- Dired listing switch tests -*- lexical-binding: t; -*-
;;; Commentary:
;; Run: emacs -Q --batch -l tests/init-local-dired-tests.el -f ert-run-tests-batch-and-exit
;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'use-package)

;; Load the module with deferral, so the `use-package' form does not load Dired.
(let ((use-package-always-defer t)
      (use-package-always-ensure nil))
  (load (expand-file-name "../user-lisp/init-local-dired.el"
                          (file-name-directory (or load-file-name buffer-file-name)))
        nil t))

(defconst init-local-dired-tests--switches "-alh --group-directories-first")

(defun init-local-dired-tests--run (program exit-code switches)
  "Return the usable SWITCHES when PROGRAM is the ls program and exits with EXIT-CODE.
The second value is the number of times the program ran."
  (let ((runs 0)
        (insert-directory-program program))
    (cl-letf (((symbol-function 'call-process)
               (lambda (&rest _) (cl-incf runs) exit-code)))
      (list (my/dired-usable-switches switches) runs))))

(ert-deftest init-local-dired-drops-the-option-when-ls-rejects-it ()
  (should (equal '("-alh" 1)
                 (init-local-dired-tests--run "ls" 2 init-local-dired-tests--switches))))

(ert-deftest init-local-dired-keeps-the-option-when-ls-accepts-it ()
  (should (equal (list init-local-dired-tests--switches 1)
                 (init-local-dired-tests--run "ls" 0 init-local-dired-tests--switches))))

(ert-deftest init-local-dired-treats-a-missing-program-as-a-rejection ()
  (let ((insert-directory-program "no-such-ls-program-for-this-test"))
    (should (equal "-alh" (my/dired-usable-switches init-local-dired-tests--switches)))))

(ert-deftest init-local-dired-leaves-ls-lisp-alone ()
  (should (equal (list init-local-dired-tests--switches 0)
                 (init-local-dired-tests--run nil 2 init-local-dired-tests--switches))))

(ert-deftest init-local-dired-skips-the-probe-without-the-option ()
  (should (equal '("-al" 0) (init-local-dired-tests--run "ls" 2 "-al"))))

(provide 'init-local-dired-tests)
;;; init-local-dired-tests.el ends here
