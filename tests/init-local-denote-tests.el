;;; init-local-denote-tests.el --- Tests for local Denote helpers -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'subr-x)

(defmacro use-package (_name &rest args)
  "Test stub for `use-package' that only evaluates :config forms."
  (let (forms)
    (while args
      (let ((key (pop args))
            (value (pop args)))
        (when (eq key :config)
          (setq forms
                (append forms
                        (if (and (listp value) (eq (car-safe value) 'progn))
                            (cdr value)
                          (list value)))))))
    `(progn ,@forms)))

(defun denote-rename-buffer-mode (&rest _args))

(load-file (expand-file-name "../lisp/init-local-denote.el" (file-name-directory load-file-name)))

(ert-deftest init-local-denote-find-latest-prior-journal-across-year-boundary ()
  (let ((files '("/tmp/20241230T090000--old__journal.md"
                 "/tmp/20250107T090000--prev__journal.md"
                 "/tmp/20250108T090000--today__journal.md")))
    (should
     (equal
      (my/denote-journal-latest-prior-file
       "2025-01-08"
       files)
      "/tmp/20250107T090000--prev__journal.md"))))

(ert-deftest init-local-denote-read-open-checkbox-lines ()
  (let ((file (make-temp-file "denote-checkbox" nil ".md"
                              "- [ ] keep me\n- [x] done\n* [ ] keep me too\n")))
    (unwind-protect
        (should
         (equal
          (my/denote-journal-open-checkbox-lines file)
          '("- [ ] keep me" "* [ ] keep me too")))
      (delete-file file))))

(ert-deftest init-local-denote-insert-carry-forward-block-once ()
  (with-temp-buffer
    (insert "# 09:00 #\n")
    (my/denote-journal-insert-carry-forward-section
     '("- [ ] keep me"))
    (my/denote-journal-insert-carry-forward-section
     '("- [ ] keep me"))
    (goto-char (point-min))
    (should (= (how-many "^## Carried Forward$" (point-min) (point-max)) 1))))

(ert-deftest init-local-denote-new-entry-with-open-todos-carries-forward-when-source-exists ()
  (let* ((source-file (make-temp-file "20250107T090000--prev__journal" nil ".md"
                                      "- [ ] carry me\n- [x] done\n"))
         (target-file "/tmp/20250108T090000--today__journal.md")
         (target-buffer (generate-new-buffer " *denote-target*")))
    (unwind-protect
        (progn
          (with-current-buffer target-buffer
            (setq buffer-file-name target-file))
          (cl-letf (((symbol-function 'denote-journal-new-or-existing-entry)
                     (lambda (&optional _date)
                       (set-buffer target-buffer)))
                    ((symbol-function 'my/denote-journal-list-files)
                     (lambda ()
                       (list source-file target-file)))
                    ((symbol-function 'denote-journal-file-is-journal-p)
                     (lambda (_file)
                       t))
                    ((symbol-function 'evil-insert-state)
                     (lambda ()
                       nil)))
            (my/denote-journal-new-entry-with-open-todos "2025-01-08")
            (my/denote-journal-new-entry-with-open-todos "2025-01-08"))
          (with-current-buffer target-buffer
            (goto-char (point-min))
            (should (= (how-many "^## Carried Forward$" (point-min) (point-max)) 1))
            (should (search-forward "- [ ] carry me" nil t))
            (should (= (how-many "^# [0-9][0-9]:[0-9][0-9] #$" (point-min) (point-max)) 2))))
      (when (file-exists-p source-file)
        (delete-file source-file))
      (when (buffer-live-p target-buffer)
        (kill-buffer target-buffer)))))
