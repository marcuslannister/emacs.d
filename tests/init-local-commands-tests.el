;;; init-local-commands-tests.el --- Small command tests -*- lexical-binding: t; -*-
;;; Commentary:
;; Run: emacs -Q --batch -l tests/init-local-commands-tests.el -f ert-run-tests-batch-and-exit
;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'ediff)

(load-file (expand-file-name "../user-lisp/init-local-commands.el"
                             (file-name-directory (or load-file-name buffer-file-name))))

(ert-deftest init-local-commands-insert-timestamp-has-the-denote-format ()
  (with-temp-buffer
    (my/insert-timestamp)
    (should (string-match-p "\\`[0-9]\\{8\\}T[0-9]\\{4\\}\\'" (buffer-string)))))

(ert-deftest init-local-commands-copy-buffer-file-name ()
  (let ((file (make-temp-file "cmd-test-"))
        (kill-ring nil))
    (unwind-protect
        (progn
          (with-current-buffer (find-file-noselect file)
            (my/copy-buffer-file-name)
            (kill-buffer))
          ;; Not `equal': on Windows the visited name can use the short form
          ;; of the user folder (RUNNER~1), while `make-temp-file' does not.
          (should (file-equal-p file (car kill-ring))))
      (delete-file file))
    (with-temp-buffer
      (should-error (my/copy-buffer-file-name) :type 'user-error))))

(ert-deftest init-local-commands-save-all-buffers-saves-without-asking ()
  (let ((file (make-temp-file "cmd-test-")))
    (unwind-protect
        (with-current-buffer (find-file-noselect file)
          (insert "changed")
          (cl-letf (((symbol-function 'y-or-n-p)
                     (lambda (&rest _) (error "no prompt may appear"))))
            (my/save-all-buffers))
          (should-not (buffer-modified-p))
          (should (equal "changed" (with-temp-buffer
                                     (insert-file-contents file)
                                     (buffer-string))))
          (kill-buffer))
      (delete-file file))))

(ert-deftest init-local-commands-ediff-needs-two-windows ()
  (save-window-excursion
    (delete-other-windows)
    (should-error (my/ediff-current-with-other-window) :type 'user-error)
    (let* ((a (generate-new-buffer " a"))
           (b (generate-new-buffer " b"))
           compared)
      (unwind-protect
          (progn
            (switch-to-buffer a)
            (set-window-buffer (split-window) b)
            (cl-letf (((symbol-function 'ediff-buffers)
                       (lambda (x y) (setq compared (list x y)))))
              (my/ediff-current-with-other-window))
            (should (equal (list a b) compared)))
        (kill-buffer a)
        (kill-buffer b)))))

(ert-deftest init-local-commands-main-window-skips-a-side-window ()
  (save-window-excursion
    (delete-other-windows)
    (let* ((main (selected-window))
           (buffer (generate-new-buffer " side"))
           (side (display-buffer-in-side-window buffer '((side . bottom)))))
      (unwind-protect
          (progn
            (should (window-live-p side))
            (select-window side)
            (should (eq main (my/main-window)))
            (select-window main)
            (should (eq main (my/main-window))))
        (when (window-live-p side) (delete-window side))
        (kill-buffer buffer)))))

(ert-deftest init-local-commands-delete-other-windows-works-from-a-side-window ()
  (save-window-excursion
    (delete-other-windows)
    (let* ((main (selected-window))
           (extra (split-window main))
           (buffer (generate-new-buffer " side"))
           (side (display-buffer-in-side-window buffer '((side . bottom)))))
      (unwind-protect
          (progn
            (select-window side)
            (my/delete-other-windows)
            ;; One main window is left, and it is selected.
            (should (window-live-p main))
            (should-not (window-live-p extra))
            (should (eq main (selected-window))))
        (when (window-live-p side) (delete-window side))
        (kill-buffer buffer)))))

(ert-deftest init-local-commands-delete-window-says-so-instead-of-failing ()
  (save-window-excursion
    (delete-other-windows)
    (let (messages)
      (cl-letf (((symbol-function 'message)
                 (lambda (format-string &rest args)
                   (push (apply #'format format-string args) messages))))
        ;; The only window of a frame cannot be deleted.
        (my/delete-window))
      (should (= 1 (length messages)))
      (should (string-match-p "Cannot delete this window" (car messages))))))

(provide 'init-local-commands-tests)
;;; init-local-commands-tests.el ends here
