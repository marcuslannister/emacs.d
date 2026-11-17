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

(defconst init-local-dired-tests--switches my/dired-date-switches)

(defun init-local-dired-tests--run (program exit-code switches)
  "Return the usable SWITCHES when PROGRAM is the ls program and exits with EXIT-CODE.
The second value is the number of times the program ran."
  (let ((runs 0)
        (insert-directory-program program))
    (cl-letf (((symbol-function 'call-process)
               (lambda (&rest _) (cl-incf runs) exit-code)))
      (list (my/dired-usable-switches switches) runs))))

(ert-deftest init-local-dired-sorts-by-date-like-the-earlier-configuration ()
  (should (equal "-Ahlt --time-style=long-iso" my/dired-date-switches)))

(ert-deftest init-local-dired-drops-the-option-when-ls-rejects-it ()
  (should (equal '("-Ahlt" 1)
                 (init-local-dired-tests--run "ls" 2 init-local-dired-tests--switches))))

(ert-deftest init-local-dired-keeps-the-option-when-ls-accepts-it ()
  (should (equal (list init-local-dired-tests--switches 1)
                 (init-local-dired-tests--run "ls" 0 init-local-dired-tests--switches))))

(ert-deftest init-local-dired-treats-a-missing-program-as-a-rejection ()
  (let ((insert-directory-program "no-such-ls-program-for-this-test"))
    (should (equal "-Ahlt" (my/dired-usable-switches init-local-dired-tests--switches)))))

(ert-deftest init-local-dired-leaves-ls-lisp-alone ()
  (should (equal (list init-local-dired-tests--switches 0)
                 (init-local-dired-tests--run nil 2 init-local-dired-tests--switches))))

(ert-deftest init-local-dired-skips-the-probe-without-the-option ()
  (should (equal '("-al" 0) (init-local-dired-tests--run "ls" 2 "-al"))))

;;;; Go to a file or its folder

(defun init-local-dired-tests--in-tree (fn)
  "Call FN with the root of a temporary tree, in a Dired buffer of that root.
The tree holds a.txt and sub/b.txt.  Then kill its Dired buffers and delete it."
  (require 'dired)
  (let ((root (file-name-as-directory (file-truename (make-temp-file "my-dired-" t)))))
    (unwind-protect
        (progn
          (make-directory (expand-file-name "sub" root))
          (write-region "" nil (expand-file-name "a.txt" root))
          (write-region "" nil (expand-file-name "sub/b.txt" root))
          (with-current-buffer (dired-noselect root)
            (funcall fn root)))
      (dolist (buffer (buffer-list))
        (when (string-prefix-p root (buffer-local-value 'default-directory buffer))
          (kill-buffer buffer)))
      (delete-directory root t))))

(ert-deftest init-local-dired-goto-opens-the-folder-of-an-unlisted-file ()
  (init-local-dired-tests--in-tree
   (lambda (root)
     (let ((file (expand-file-name "sub/b.txt" root)))
       (my/dired-goto-file-or-folder file)
       (should (derived-mode-p 'dired-mode))
       (should (file-equal-p file (dired-get-filename nil t)))))))

(ert-deftest init-local-dired-goto-stops-at-a-missing-file ()
  (init-local-dired-tests--in-tree
   (lambda (root)
     (let ((buffer (current-buffer)))
       (should-error (my/dired-goto-file-or-folder (expand-file-name "typo.txt" root))
                     :type 'user-error)
       (should-error (my/dired-goto-file-or-folder (expand-file-name "no-such/b.txt" root))
                     :type 'user-error)
       (should (eq buffer (current-buffer)))))))

(ert-deftest init-local-dired-goto-keeps-a-killed-line-hidden ()
  ;; `dired-jump' would read the folder again, and the line would come back.
  (init-local-dired-tests--in-tree
   (lambda (root)
     (let ((file (expand-file-name "a.txt" root)))
       (dired-goto-file file)
       (dired-kill-line)
       (should-error (my/dired-goto-file-or-folder file) :type 'user-error)
       (should-not (dired-goto-file file))))))

(provide 'init-local-dired-tests)
;;; init-local-dired-tests.el ends here
