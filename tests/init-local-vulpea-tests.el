;;; init-local-vulpea-tests.el --- Vulpea start tests -*- lexical-binding: t; -*-
;;; Commentary:
;; Run: emacs -Q --batch -l tests/init-local-vulpea-tests.el -f ert-run-tests-batch-and-exit
;; Vulpea is not installed here: the tests give the module a fake `vulpea' feature.
;;; Code:

(require 'cl-lib)
(require 'ert)
(require 'use-package)

(defvar init-local-vulpea-tests--keys nil "The (KEY . COMMAND) pairs that the module binds.")
(defun my/hel-leader-bind (&rest args)
  "Record the KEY COMMAND pairs in ARGS."
  (while args
    (push (cons (pop args) (pop args)) init-local-vulpea-tests--keys)))

;; Load with deferral and without package installs.
(let ((use-package-always-defer t)
      (use-package-always-ensure nil)
      (use-package-ensure-function #'ignore))
  (load (expand-file-name "../user-lisp/init-local-vulpea.el"
                          (file-name-directory (or load-file-name buffer-file-name)))
        nil t))

(defun init-local-vulpea-tests--start (&rest options)
  "Run `my/vulpea-start' and return a plist with its effects.
OPTIONS: `:package' non-nil gives the fake `vulpea' feature, and `:fail' makes the
autosync mode signal an error."
  (let ((warnings nil) (modes nil)
        (saved-features features)
        (saved-load-path load-path))
    ;; Set these with `setq': a `let' binding of `features' has no effect under
    ;; lexical binding in Emacs 31.
    (unwind-protect
        (progn
          (setq features (if (plist-get options :package)
                             (cons 'vulpea features)
                           (remq 'vulpea features))
                load-path nil)
          (add-hook 'org-mode-hook #'my/vulpea-start)
          (cl-letf (((symbol-function 'display-warning)
                     (lambda (type message &rest _) (push (cons type message) warnings)))
                    ((symbol-function 'vulpea-db-autosync-mode)
                     (lambda (&optional arg)
                       (push arg modes)
                       (when (plist-get options :fail) (error "boom")))))
            (my/vulpea-start)))
      (setq features saved-features
            load-path saved-load-path)
      (remove-hook 'org-mode-hook #'my/vulpea-start))
    (list :warnings (nreverse warnings) :modes modes
          :hook-removed (not (memq #'my/vulpea-start org-mode-hook)))))

(ert-deftest init-local-vulpea-registers-the-start-on-org-buffers ()
  (should (memq #'my/vulpea-start org-mode-hook)))

(ert-deftest init-local-vulpea-start-turns-on-autosync-once ()
  (let ((result (init-local-vulpea-tests--start :package t)))
    (should (equal '(1) (plist-get result :modes)))
    (should-not (plist-get result :warnings))
    (should (plist-get result :hook-removed))))

(ert-deftest init-local-vulpea-start-warns-when-the-package-is-missing ()
  (let* ((result (init-local-vulpea-tests--start))
         (warnings (plist-get result :warnings)))
    (should-not (plist-get result :modes))
    (should (= 1 (length warnings)))
    (should (eq 'init-local-vulpea (car (car warnings))))
    (should (string-match-p "Vulpea unavailable" (cdr (car warnings))))
    (should (plist-get result :hook-removed))))

(ert-deftest init-local-vulpea-start-warns-when-the-mode-fails ()
  (let* ((result (init-local-vulpea-tests--start :package t :fail t))
         (warnings (plist-get result :warnings)))
    (should (= 1 (length warnings)))
    (should (string-match-p "Vulpea unavailable: boom" (cdr (car warnings))))
    (should (plist-get result :hook-removed))))

(ert-deftest init-local-vulpea-autoloads-the-tag-commands-that-the-package-does-not ()
  (dolist (command '(vulpea-buffer-tags-add vulpea-buffer-tags-remove))
    (should (autoloadp (symbol-function command)))
    (should (commandp command))))

(ert-deftest init-local-vulpea-binds-the-note-keys ()
  (should (equal '(("C-c v f" . vulpea-find)
                   ("C-c v i" . vulpea-insert)
                   ("C-c v a" . vulpea-buffer-tags-add)
                   ("C-c v A" . vulpea-buffer-tags-remove)
                   ("C-c v u" . vulpea-db-sync-full-scan)
                   ("C-c v b" . vulpea-find-backlink))
                 (reverse init-local-vulpea-tests--keys))))

(provide 'init-local-vulpea-tests)
;;; init-local-vulpea-tests.el ends here
