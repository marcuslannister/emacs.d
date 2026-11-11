;;; init-local-auto-save-tests.el --- Tests for init-local-auto-save -*- lexical-binding: t -*-
(require 'ert)
(require 'cl-lib)
(defvar nn-first-file-hook nil)
(add-to-list 'load-path (expand-file-name "../user-lisp" (file-name-directory load-file-name)))
(require 'init-local-auto-save)
(require 'warnings)

(ert-deftest init-local-auto-save-missing-checkout-warns-and-adds-no-hook ()
  (let ((my/auto-save-directory "/nonexistent/auto-save/") (nn-first-file-hook nil) warned)
    (cl-letf (((symbol-function 'display-warning) (lambda (&rest args) (setq warned args))))
      (my/auto-save-register))
    (should warned)
    (should (string-match-p "/nonexistent/auto-save/" (nth 1 warned)))
    (should-not nn-first-file-hook)))

(ert-deftest init-local-auto-save-present-checkout-turns-it-on-with-the-first-file ()
  (let* ((dir (make-temp-file "auto-save-" t))
         (my/auto-save-directory (file-name-as-directory dir))
         (nn-first-file-hook nil) (load-path load-path) (features features) enabled)
    (unwind-protect
        (progn
          (with-temp-file (expand-file-name "auto-save.el" dir)
            (insert ";;; -*- lexical-binding: t -*-
" "(defun auto-save-enable () (setq init-local-auto-save-tests--on t))\n"
                    "(provide 'auto-save)\n"))
          (defvar init-local-auto-save-tests--on nil)
          (my/auto-save-register)
          (should (memq #'my/auto-save-setup nn-first-file-hook))
          (my/auto-save-setup)
          (should init-local-auto-save-tests--on)
          (should auto-save-silent)
          (setq enabled t))
      (setq features (delq 'auto-save features))
      (delete-directory dir t))
    (should enabled)))

(ert-deftest init-local-auto-save-skips-gpg-files ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/secret.gpg")
    (should (my/auto-save-gpg-buffer-p))
    (setq buffer-file-name "/tmp/notes.org")
    (should-not (my/auto-save-gpg-buffer-p))))

(provide 'init-local-auto-save-tests)
;;; init-local-auto-save-tests.el ends here
