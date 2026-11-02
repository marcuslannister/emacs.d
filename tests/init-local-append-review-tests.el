;;; init-local-append-review-tests.el --- Append-and-review tests -*- lexical-binding: t; -*-

;; Run: emacs -Q --batch -l tests/init-local-append-review-tests.el -f ert-run-tests-batch-and-exit

(require 'cl-lib)
(require 'ert)
(require 'org)
(require 'org-capture)

(load-file (expand-file-name "../lisp/init-local-append-review.el"
                             (file-name-directory load-file-name)))

(defun init-local-append-review-tests--move (heading target)
  "Move HEADING to the top of section TARGET; return the buffer text."
  (let ((file (make-temp-file "ar" nil ".org"
                              "* Today\n** T1\n* Inbox\n** A\n** B\n*** B1\n")))
    (unwind-protect
        (with-current-buffer (find-file-noselect file)
          (goto-char (point-min))
          (re-search-forward (concat "^\\*+ " heading "$"))
          (beginning-of-line)
          (cl-letf (((symbol-function 'completing-read)
                     (lambda (_prompt coll &rest _)
                       (car (seq-find (lambda (c) (string-prefix-p target (car c))) coll)))))
            (init-local-append-review-to-top))
          (prog1 (buffer-string)
            (set-buffer-modified-p nil)
            (kill-buffer)))
      (delete-file file))))

(ert-deftest init-local-append-review-to-top-same-section ()
  (should (equal (init-local-append-review-tests--move "B" "Inbox")
                 "* Today\n** T1\n* Inbox\n** B\n*** B1\n** A\n")))

(ert-deftest init-local-append-review-to-top-other-section ()
  (should (equal (init-local-append-review-tests--move "B" "Today")
                 "* Today\n** B\n*** B1\n** T1\n* Inbox\n** A\n")))

(ert-deftest init-local-append-review-to-top-refuses-section ()
  (should-error (init-local-append-review-tests--move "Inbox" "Today")
                :type 'user-error))

(defun init-local-append-review-tests--run (command heading &optional target)
  "Run COMMAND on HEADING in a temp `notes.org'; return the buffer text.
TARGET is the section a prompting command picks."
  (let* ((org-directory (make-temp-file "ar" t))
         (file (expand-file-name "notes.org" org-directory)))
    (unwind-protect
        (progn
          (with-temp-file file (insert "* Today\n** T1\n* Inbox\n** A\n** B\n"))
          (with-current-buffer (find-file-noselect file)
            (goto-char (point-min))
            (re-search-forward (concat "^\\*+ " heading "$"))
            (beginning-of-line)
            (cl-letf (((symbol-function 'completing-read)
                       (lambda (_prompt coll &rest _)
                         (car (seq-find (lambda (c) (string-prefix-p target (car c))) coll)))))
              (funcall command))
            (prog1 (buffer-string)
              (set-buffer-modified-p nil)
              (kill-buffer))))
      (delete-directory org-directory t))))

(ert-deftest init-local-append-review-to-bottom ()
  (should (equal (init-local-append-review-tests--run
                  #'init-local-append-review-to-bottom "A" "Inbox")
                 "* Today\n** T1\n* Inbox\n** B\n** A\n"))
  (should (equal (init-local-append-review-tests--run
                  #'init-local-append-review-to-bottom "A" "Today")
                 "* Today\n** T1\n** A\n* Inbox\n** B\n")))

(ert-deftest init-local-append-review-to-today-and-inbox ()
  (should (equal (init-local-append-review-tests--run
                  #'init-local-append-review-to-today "B")
                 "* Today\n** B\n** T1\n* Inbox\n** A\n"))
  (should (equal (init-local-append-review-tests--run
                  #'init-local-append-review-to-inbox "T1")
                 "* Today\n* Inbox\n** T1\n** A\n** B\n")))

(ert-deftest init-local-append-review-capture-lands-on-top-of-inbox ()
  (let* ((org-directory (make-temp-file "ar" t))
         (file (expand-file-name "notes.org" org-directory)))
    (unwind-protect
        (progn
          (with-temp-file file (insert "* Today\n\n* Inbox\n** old\n"))
          (init-local-append-review-capture)
          (insert "new")
          (org-capture-finalize)
          (with-current-buffer (find-buffer-visiting file)
            (should (equal (buffer-string) "* Today\n\n* Inbox\n** new\n** old\n"))
            (set-buffer-modified-p nil)
            (kill-buffer)))
      (delete-directory org-directory t))))

;;; init-local-append-review-tests.el ends here
