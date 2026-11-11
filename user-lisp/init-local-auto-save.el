;;; init-local-auto-save.el --- Save file buffers when Emacs is idle -*- lexical-binding: t -*-
;;; Commentary:
;; auto-save (manateelazycat) saves each modified file buffer after a short idle time,
;; so there are no temporary files to clean up.  It is a checkout, not a package: the
;; folder is `my/auto-save-directory'.  When it is missing (CI, a new machine) the
;; module warns once and does nothing; it never stops startup.
;;
;; The package starts with the first file that opens (`nn-first-file-hook').  It does
;; not trim whitespace: ws-butler does that for programming buffers.  The case guard
;; already covers the saves that this timer makes (see init-local-case-guard.el).
;;; Code:

(defvar my/auto-save-directory (expand-file-name "~/github/auto-save/")
  "Folder of the auto-save checkout.")

(declare-function auto-save-enable "auto-save")
(defvar auto-save-silent)
(defvar auto-save-disable-predicates)

(defun my/auto-save-gpg-buffer-p ()
  "Return non-nil when the current buffer visits a gpg file, which must not auto-save."
  (string-suffix-p ".gpg" (or buffer-file-name "") t))

(defun my/auto-save-setup ()
  "Turn on auto-save from its checkout."
  (add-to-list 'load-path my/auto-save-directory)
  (require 'auto-save)
  (setq auto-save-silent t
        auto-save-disable-predicates '(my/auto-save-gpg-buffer-p))
  (auto-save-enable))

(defun my/auto-save-register ()
  "Start auto-save with the first file, or warn when its checkout is missing."
  (if (file-directory-p my/auto-save-directory)
      (add-hook 'nn-first-file-hook #'my/auto-save-setup)
    (display-warning 'init-local
                     (format "auto-save is missing: buffers will NOT be saved automatically.
Clone manateelazycat/auto-save to %s and restart Emacs." my/auto-save-directory)
                     :warning)))

(my/auto-save-register)

(provide 'init-local-auto-save)
;;; init-local-auto-save.el ends here
