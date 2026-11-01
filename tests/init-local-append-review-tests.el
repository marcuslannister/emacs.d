;;; init-local-append-review-tests.el --- Append-and-review tests -*- lexical-binding: t; -*-

;; Run: emacs -Q --batch -l tests/init-local-append-review-tests.el -f ert-run-tests-batch-and-exit

(require 'ert)
(require 'org)
(require 'org-capture)

(load-file (expand-file-name "../lisp/init-local-append-review.el"
                             (file-name-directory load-file-name)))

(ert-deftest init-local-append-review-to-top-moves-subtree ()
  (let ((file (make-temp-file "ar" nil ".org" "#+TITLE: Notes\n\n* A\n* B\n** B1\n* C\n")))
    (unwind-protect
        (with-current-buffer (find-file-noselect file)
          (goto-char (point-min))
          (re-search-forward "^\\* B")
          (beginning-of-line)
          (init-local-append-review-to-top)
          (should (equal (buffer-string) "#+TITLE: Notes\n\n* B\n** B1\n* A\n* C\n"))
          (set-buffer-modified-p nil)
          (kill-buffer))
      (delete-file file))))

(ert-deftest init-local-append-review-capture-template-prepends ()
  (let ((tpl (assoc "a" org-capture-templates)))
    (should tpl)
    (should (eq (plist-get (nthcdr 5 tpl) :prepend) t))))

;;; init-local-append-review-tests.el ends here
