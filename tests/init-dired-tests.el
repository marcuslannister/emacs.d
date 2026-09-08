;;; init-dired-tests.el --- Tests for the diff-hl-dired kill-query advice -*- lexical-binding: t; -*-

(require 'ert)

(defun maybe-require-package (package &rest _)
  "Pretend only PACKAGE `diff-hl' is installed.
Claiming the others would run `diredfl-global-mode' at load time."
  (eq package 'diff-hl))

;; `with-eval-after-load' runs its body immediately for a feature that is
;; already provided, so faking this one makes the diff-hl hookup happen during
;; `load-file' below without the package itself being installed.  The `dired'
;; feature is deliberately left alone: that block stays deferred.
(provide 'diff-hl-dired)

(load-file (expand-file-name "../lisp/init-dired.el"
                             (file-name-directory load-file-name)))

(defun init-dired-tests--status-files (_backend _dir _files update-function)
  "Stand in for `diff-hl-dired-status-files', calling UPDATE-FUNCTION once."
  (funcall update-function '(entry) nil))

(ert-deftest init-dired-diff-hl-advice-is-installed ()
  "Loading init-dired.el advises `diff-hl-dired-status-files'."
  (should (advice-member-p #'sanityinc/diff-hl-dired-status-files-no-query
                           'diff-hl-dired-status-files)))

(ert-deftest init-dired-diff-hl-wrapper-suppresses-kill-buffer-query ()
  "The wrapper runs its callback with `kill-buffer-query-functions' nil.
That is what stops `diff-hl-dired-update' from asking to confirm the kill
of its temp status buffer while a status process is still live."
  (let ((kill-buffer-query-functions '(ignore))
        seen-hooks)
    (sanityinc/diff-hl-dired-status-files-no-query
     #'init-dired-tests--status-files 'Git "/tmp/" nil
     (lambda (_entries &optional _more)
       (setq seen-hooks kill-buffer-query-functions)))
    (should-not seen-hooks)))

(provide 'init-dired-tests)
;;; init-dired-tests.el ends here
