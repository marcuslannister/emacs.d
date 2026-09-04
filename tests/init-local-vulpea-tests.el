;;; init-local-vulpea-tests.el --- Smoke test for Vulpea setup -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'ert)

(defvar vulpea-db-sync-external-method)

(ert-deftest init-local-vulpea-keeps-only-the-note-index ()
  (let ((user-emacs-directory (file-name-as-directory temporary-file-directory))
        (vulpea-db-sync-external-method 'auto)
        autosync-arg)
    (cl-letf (((symbol-function 'maybe-require-package) (lambda (&rest _args) t))
              ((symbol-function 'require) (lambda (&rest _args) t))
              ((symbol-function 'vulpea-db-autosync-mode)
               (lambda (&optional arg) (setq autosync-arg arg))))
      (load-file (expand-file-name "lisp/init-local-vulpea.el"))
      (should (= 1 autosync-arg))
      (should-not vulpea-db-sync-external-method)
      (should
       (equal (expand-file-name "var/vulpea/vulpea.db" user-emacs-directory)
              vulpea-db-location))
      (should-not (fboundp 'my/vulpea-task-table)))))

(provide 'init-local-vulpea-tests)
;;; init-local-vulpea-tests.el ends here
