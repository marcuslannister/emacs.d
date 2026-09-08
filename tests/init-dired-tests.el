;;; init-dired-tests.el --- Tests for the diff-hl-dired kill-query advice -*- lexical-binding: t; -*-

(require 'ert)

;; init-dired.el only defines the advice at top level; the package hookup is
;; guarded by `maybe-require-package', which is stubbed out here.
(defun maybe-require-package (&rest _) nil)

(load-file (expand-file-name "../lisp/init-dired.el"
                             (file-name-directory load-file-name)))

(defun init-dired-tests--status-files (backend dir files update-function)
  "Stand in for `diff-hl-dired-status-files', calling back once as it finishes."
  (list backend dir files (funcall update-function '(entry) nil)))

(ert-deftest init-dired-diff-hl-advice-passes-arguments-through ()
  "The advice forwards backend, dir and files untouched."
  (advice-add 'init-dired-tests--status-files :around
              #'sanityinc/diff-hl-dired-status-files-no-query)
  (unwind-protect
      (let (seen-entries)
        (should (equal (butlast (init-dired-tests--status-files
                                 'Git "/tmp/" '("a")
                                 (lambda (entries &optional _more)
                                   (setq seen-entries entries))))
                       '(Git "/tmp/" ("a"))))
        (should (equal seen-entries '(entry))))
    (advice-remove 'init-dired-tests--status-files
                   #'sanityinc/diff-hl-dired-status-files-no-query)))

(ert-deftest init-dired-diff-hl-advice-suppresses-kill-buffer-query ()
  "The callback runs with `kill-buffer-query-functions' bound to nil.
That is what stops `diff-hl-dired-update' from asking to confirm the kill
of its temp status buffer while a status process is still live."
  (advice-add 'init-dired-tests--status-files :around
              #'sanityinc/diff-hl-dired-status-files-no-query)
  (unwind-protect
      (let ((kill-buffer-query-functions '(ignore))
            seen-hooks)
        (init-dired-tests--status-files
         'Git "/tmp/" nil
         (lambda (_entries &optional _more)
           (setq seen-hooks kill-buffer-query-functions)))
        (should-not seen-hooks)
        ;; The binding is dynamic, so it is gone again afterwards.
        (should (equal kill-buffer-query-functions '(ignore))))
    (advice-remove 'init-dired-tests--status-files
                   #'sanityinc/diff-hl-dired-status-files-no-query)))

(provide 'init-dired-tests)
;;; init-dired-tests.el ends here
