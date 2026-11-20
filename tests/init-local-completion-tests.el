;;; init-local-completion-tests.el --- Completion icon advice tests -*- lexical-binding: t; -*-
;;; Commentary:
;; Run: emacs -Q --batch -l tests/init-local-completion-tests.el -f ert-run-tests-batch-and-exit
;; marginalia and nerd-icons-completion are not loaded: the tests give the module
;; `use-package' without installs, and call the advice function directly.
;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'use-package)
(require 'icomplete)

(let ((use-package-always-defer t)
      (use-package-always-ensure nil)
      (use-package-ensure-function #'ignore))
  (load (expand-file-name "../user-lisp/init-local-completion.el"
                          (file-name-directory (or load-file-name buffer-file-name)))
        nil t))

(defun init-local-completion-tests--call (in-minibuffer)
  "Call the advice with a fake icon function and original; return which one ran."
  (cl-letf (((symbol-function 'minibufferp) (lambda (&rest _) in-minibuffer)))
    (my/completion-icons-in-minibuffer-only
     (lambda (_orig _metadata _prop) 'icon-advice)
     (lambda (_metadata _prop) 'original)
     'metadata 'affixation-function)))

(ert-deftest init-local-completion-icons-apply-in-the-minibuffer ()
  (should (eq 'icon-advice (init-local-completion-tests--call t))))

(ert-deftest init-local-completion-icons-skip-the-in-buffer-popup ()
  ;; corfu has its own icons (nerd-icons-corfu); a second icon would show per row.
  (should (eq 'original (init-local-completion-tests--call nil))))

(ert-deftest init-local-completion-passes-the-arguments-through ()
  (let (seen)
    (cl-letf (((symbol-function 'minibufferp) (lambda (&rest _) nil)))
      (my/completion-icons-in-minibuffer-only
       #'ignore (lambda (metadata prop) (setq seen (list metadata prop))) 'm 'p))
    (should (equal '(m p) seen))))

(ert-deftest init-local-completion-tab-inserts-the-fido-selection ()
  (should (eq 'icomplete-force-complete (keymap-lookup icomplete-fido-mode-map "TAB"))))

(ert-deftest init-local-completion-files-sort-newest-first ()
  (let* ((dir (make-temp-file "fido-files-" t))
         (older (expand-file-name "a-older.el" dir))
         (newer (expand-file-name "z-newer.el" dir)))
    (unwind-protect
        (progn
          (write-region "" nil older)
          (write-region "" nil newer)
          (set-file-times older (seconds-to-time 1000000000))
          (set-file-times newer (seconds-to-time 1000000100))
          (with-temp-buffer
            (let ((fido-mode t)
                  (minibuffer-completing-file-name t)
                  (minibuffer-completion-table #'read-file-name-internal)
                  (completion-styles '(flex)))
              (insert (file-name-as-directory dir) ".el")
              (run-hooks 'minibuffer-setup-hook)
              (should (equal (seq-take (completion-all-sorted-completions (point-min) (point)) 2)
                             '("z-newer.el" "a-older.el"))))))
      (delete-directory dir t))))

(provide 'init-local-completion-tests)
;;; init-local-completion-tests.el ends here
