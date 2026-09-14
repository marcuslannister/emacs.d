;;; init-local-hel-tests.el --- Hel mouse regression test -*- lexical-binding: t; -*-
;;; Commentary:
;; Run: emacs -Q --batch -l tests/init-local-hel-tests.el -f ert-run-tests-batch-and-exit
;;; Code:

(require 'cl-lib)
(require 'ert)

(defvar hel-whitelist-file)

(let* ((root (file-name-directory
              (directory-file-name
               (file-name-directory (or load-file-name buffer-file-name)))))
       (user-emacs-directory root)
       ;; Do not read or write the user's saved cursor-command choices.
       (hel-whitelist-file (make-temp-name
                            (expand-file-name "hel-test-" temporary-file-directory))))
  (dolist (directory (directory-files root t "\\`elpa-"))
    (when (file-directory-p directory)
      (dolist (package (directory-files directory t "\\`[^.]"))
        (when (file-directory-p package)
          (add-to-list 'load-path package)))))
  (cl-letf (((symbol-function 'require-package) #'ignore))
    (load (expand-file-name "lisp/init-local-hel.el" root) nil t)))

(ert-deftest init-local-hel-mouse-selection-does-not-prompt-recursively ()
  "Mouse selection must not enter Hel's multiple-cursor prompt."
  (skip-unless (and (featurep 'hel) (featurep 'hel-leader)))
  (with-temp-buffer
    (insert "abc")
    (hel-local-mode 1)
    (hel-create-fake-cursor 2)
    (should (= (hel-number-of-cursors) 2))
    (let ((prompts 0)
          (replays 0)
          (hel-this-command 'mouse-set-region))
      (cl-letf (((symbol-function 'y-or-n-p)
                 (lambda (&rest _)
                   (cl-incf prompts)
                   ;; Replay a post-command event while the prompt is open.
                   ;; Stop at two entries instead of opening a real minibuffer.
                   (when (= prompts 1)
                     (hel--post-command-hook))
                   nil))
                ((symbol-function 'hel--call-interactively)
                 (lambda (&rest _) (cl-incf replays)))
                ((symbol-function 'hel-save-whitelists-into-file) #'ignore))
        (hel--post-command-hook))
      (should (= prompts 0))
      (should (= replays 0)))))

;;; init-local-hel-tests.el ends here
