;;; init-local-denote-tests.el --- Denote journal helper tests -*- lexical-binding: t; -*-
;;; Commentary:
;; Run: emacs -Q --batch -l tests/init-local-denote-tests.el -f ert-run-tests-batch-and-exit
;; Denote is not loaded: the tests stub what the module calls from it.
;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'use-package)

(defvar denote-journal-directory)

(defvar init-local-denote-tests--keys nil "The (KEY . COMMAND) pairs that the module binds.")
(defun my/hel-leader-bind (&rest args)
  "Record the KEY COMMAND pairs in ARGS."
  (while args
    (push (cons (pop args) (pop args)) init-local-denote-tests--keys)))

;; Load with deferral and without package installs.
(let ((use-package-always-defer t)
      (use-package-always-ensure nil)
      (use-package-ensure-function #'ignore))
  (load (expand-file-name "../user-lisp/init-local-denote.el"
                          (file-name-directory (or load-file-name buffer-file-name)))
        nil t))

(defmacro init-local-denote-tests--with-files (files &rest body)
  "Run BODY with `dir' bound to a temp folder that holds FILES, a list of (NAME . TEXT)."
  (declare (indent 1))
  `(let ((dir (file-name-as-directory (make-temp-file "denote-test" t))))
     (unwind-protect
         (progn
           (dolist (file ,files)
             (write-region (cdr file) nil (expand-file-name (car file) dir)))
           ,@body)
       (delete-directory dir t))))

;;;; Identifiers and days

(ert-deftest init-local-denote-identifier-comes-from-the-file-name ()
  (should (equal "20260102T030405"
                 (my/denote-journal--file-identifier "/x/20260102T030405--title__journal.md")))
  (should-not (my/denote-journal--file-identifier "/x/notes.md")))

(ert-deftest init-local-denote-target-day-takes-a-string-a-time-or-nil ()
  (should (equal "20260304" (my/denote-journal--target-day "2026-03-04")))
  (should (equal "20260304" (my/denote-journal--target-day (encode-time 0 0 12 4 3 2026))))
  (should (equal (format-time-string "%Y%m%d") (my/denote-journal--target-day nil))))

(ert-deftest init-local-denote-latest-prior-file-is-the-latest-before-the-day ()
  (let ((files '("/j/20260101T100000--a__journal.md"
                 "/j/20260103T090000--c__journal.md"
                 "/j/20260102T200000--b__journal.md"
                 "/j/20260105T100000--e__journal.md")))
    (should (equal "/j/20260103T090000--c__journal.md"
                   (my/denote-journal-latest-prior-file "2026-01-05" files)))
    (should (equal "/j/20260101T100000--a__journal.md"
                   (my/denote-journal-latest-prior-file "2026-01-02" files)))
    (should-not (my/denote-journal-latest-prior-file "2026-01-01" files))
    (should-not (my/denote-journal-latest-prior-file "2026-01-05" nil))))

;;;; Checkbox lines and sections

(ert-deftest init-local-denote-open-checkbox-lines-skip-finished-ones ()
  (init-local-denote-tests--with-files
      '(("a.md" . "# Day\n- [ ] one  \n- [x] done\n* [ ] two\n  + [ ] nested\ntext [ ] not a todo\n"))
    (should (equal '("- [ ] one" "* [ ] two" "  + [ ] nested")
                   (my/denote-journal-open-checkbox-lines (expand-file-name "a.md" dir))))))

(ert-deftest init-local-denote-carry-forward-section-is-added-once ()
  (with-temp-buffer
    (insert "text")
    (my/denote-journal-insert-carry-forward-section '("- [ ] a" "- [ ] b"))
    (should (equal "text\n\n## Carried Forward\n\n- [ ] a\n- [ ] b\n\n" (buffer-string)))
    (my/denote-journal-insert-carry-forward-section '("- [ ] c"))
    (should (equal "text\n\n## Carried Forward\n\n- [ ] a\n- [ ] b\n\n" (buffer-string)))))

(ert-deftest init-local-denote-carry-forward-adds-nothing-without-items ()
  (with-temp-buffer
    (insert "text")
    (my/denote-journal-insert-carry-forward-section nil)
    (should (equal "text" (buffer-string)))))

(ert-deftest init-local-denote-blank-line-is-added-only-when-needed ()
  (dolist (case '(("" . "") ("a" . "a\n\n") ("a\n" . "a\n\n") ("a\n\n" . "a\n\n")))
    (with-temp-buffer
      (insert (car case))
      (my/denote-journal--ensure-blank-line-before-point-max)
      (should (equal (cdr case) (buffer-string))))))

(ert-deftest init-local-denote-timestamp-heading-ends-the-buffer ()
  (with-temp-buffer
    (insert "text")
    (my/denote-journal-insert-timestamp)
    (should (string-match-p "\\`text\n\n# [0-9][0-9]:[0-9][0-9] #\n\n\\'" (buffer-string)))))

;;;; Entries

(defmacro init-local-denote-tests--entry (open-file &rest body)
  "Run BODY after a stubbed Denote Journal opens the entry file OPEN-FILE in DIR.
`dir' holds the journal files, and the entry file is a new, empty file there."
  (declare (indent 1))
  `(init-local-denote-tests--with-files
       '(("20260101T100000--old__journal.md" . "- [ ] carried\n- [x] done\n")
         ("20260102T100000--note__other.md" . "- [ ] not a journal\n"))
     (let ((denote-journal-directory dir)
           buffer)
       (cl-letf (((symbol-function 'denote-journal-file-is-journal-p)
                  (lambda (file) (string-match-p "__journal" file)))
                 ((symbol-function 'denote-journal-new-or-existing-entry)
                  (lambda (&optional _date)
                    (setq buffer (find-file-noselect (expand-file-name ,open-file dir)))
                    (set-buffer buffer))))
         (unwind-protect (progn ,@body)
           (when (buffer-live-p buffer)
             (with-current-buffer buffer (set-buffer-modified-p nil))
             (kill-buffer buffer)))))))

(ert-deftest init-local-denote-new-entry-gets-a-timestamp ()
  (init-local-denote-tests--entry "20260102T120000--new__journal.md"
    (my/denote-journal-new-or-existing-entry)
    (should (string-match-p "\\`# [0-9][0-9]:[0-9][0-9] #\n\n\\'" (buffer-string)))))

(ert-deftest init-local-denote-new-entry-with-todos-carries-the-open-ones ()
  (init-local-denote-tests--entry "20260102T120000--new__journal.md"
    (my/denote-journal-new-entry-with-open-todos)
    (should (string-match-p
             "\\`## Carried Forward\n\n- \\[ \\] carried\n\n# [0-9][0-9]:[0-9][0-9] #\n\n\\'"
             (buffer-string)))))

(ert-deftest init-local-denote-new-entry-with-todos-adds-no-section-without-an-earlier-file ()
  (init-local-denote-tests--entry "20251231T120000--new__journal.md"
    (my/denote-journal-new-entry-with-open-todos)
    (should (string-match-p "\\`# [0-9][0-9]:[0-9][0-9] #\n\n\\'" (buffer-string)))))

(ert-deftest init-local-denote-entry-commands-leave-a-non-journal-buffer-alone ()
  (init-local-denote-tests--entry "20260102T120000--new__other.md"
    (my/denote-journal-new-or-existing-entry)
    (should (equal "" (buffer-string)))
    (my/denote-journal-new-entry-with-open-todos)
    (should (equal "" (buffer-string)))))

;;;; Keys

(ert-deftest init-local-denote-binds-the-note-and-journal-keys ()
  (should (equal '(("C-c d n" . denote)
                   ("C-c d r" . denote-rename-file)
                   ("C-c j n" . my/denote-journal-new-or-existing-entry)
                   ("C-c j t" . my/denote-journal-new-entry-with-open-todos)
                   ("C-c j o" . denote-journal-new-or-existing-entry))
                 (reverse init-local-denote-tests--keys)))
  ;; Denote's own commands come from its package autoloads; test-startup.sh checks them.
  (should (fboundp 'my/denote-journal-new-or-existing-entry))
  (should (fboundp 'my/denote-journal-new-entry-with-open-todos)))

(provide 'init-local-denote-tests)
;;; init-local-denote-tests.el ends here
