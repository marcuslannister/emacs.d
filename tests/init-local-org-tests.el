;;; init-local-org-tests.el --- Org module tests -*- lexical-binding: t; -*-
;;; Commentary:
;; Run: emacs -Q --batch -l tests/init-local-org-tests.el -f ert-run-tests-batch-and-exit
;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'use-package)

(defvar org-directory)

;; The module adds its keys through Hel, which these tests do not load.
(defvar init-local-org-tests--keys nil "The (KEY . COMMAND) pairs that the module binds.")
(defun my/hel-leader-bind (&rest args)
  "Record the KEY COMMAND pairs in ARGS."
  (while args
    (push (cons (pop args) (pop args)) init-local-org-tests--keys)))

;; Load with deferral, so the `use-package' forms do not load Org or install anything.
(let ((use-package-always-defer t)
      (use-package-always-ensure nil))
  (load (expand-file-name "../user-lisp/init-local-org.el"
                          (file-name-directory (or load-file-name buffer-file-name)))
        nil t))

(defun init-local-org-tests--agenda-files (files)
  "Make FILES (relative names) in a temp `org-directory'; return the agenda file names."
  (let* ((dir (file-name-as-directory (make-temp-file "org-test" t)))
         (org-directory dir))
    (unwind-protect
        (progn
          (dolist (file files)
            (make-directory (file-name-directory (expand-file-name file dir)) t)
            (write-region "" nil (expand-file-name file dir)))
          (sort (mapcar (lambda (f) (file-relative-name f dir)) (my/org-agenda-files))
                #'string<))
      (delete-directory dir t))))

(ert-deftest init-local-org-agenda-files-take-every-org-file ()
  (should (equal '("a.org" "sub/b.org")
                 (init-local-org-tests--agenda-files '("a.org" "sub/b.org" "notes.txt")))))

(ert-deftest init-local-org-agenda-files-skip-versions-and-the-inbox ()
  (should (equal '("a.org")
                 (init-local-org-tests--agenda-files
                  '("a.org" ".stversions/old.org" "sub/.stversions/old.org" "gtd/inbox.org")))))

(ert-deftest init-local-org-agenda-files-keep-other-gtd-files ()
  (should (equal '("gtd/org-gtd-tasks.org")
                 (init-local-org-tests--agenda-files '("gtd/org-gtd-tasks.org" "gtd/inbox.org")))))

(ert-deftest init-local-org-agenda-files-are-empty-without-the-folder ()
  (let ((org-directory "/no/such/folder/for/this/test/"))
    (should-not (my/org-agenda-files))))

(ert-deftest init-local-org-leader-commands-exist-before-org-loads ()
  ;; A leader key must run a defined command at startup, when Org is not loaded.
  (should init-local-org-tests--keys)
  (dolist (binding init-local-org-tests--keys)
    (should (fboundp (cdr binding)))))

(provide 'init-local-org-tests)
;;; init-local-org-tests.el ends here
