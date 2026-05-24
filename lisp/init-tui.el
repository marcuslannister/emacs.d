;;; init-tui.el --- Minimal terminal configuration -*- lexical-binding: t -*-
;;; Commentary:
;;; Code:

(require 'ediff)

(setq-default
 ediff-split-window-function 'split-window-horizontally
 ediff-window-setup-function 'ediff-setup-windows-plain
 indent-tabs-mode nil
 create-lockfiles nil
 auto-save-default nil
 make-backup-files nil)

(defun insert-timestamp ()
  "Insert current timestamp in format YYYYMMDDTHHMM."
  (interactive)
  (insert (format-time-string "%Y%m%dT%H%M")))

(defun ml-init-ediff-current-with-other-window ()
  "Ediff current window buffer with the next window buffer."
  (interactive)
  (if (< (count-windows) 2)
      (user-error "Need at least two windows")
    (ediff-buffers (window-buffer)
                   (window-buffer (next-window (selected-window) 0)))))

(require 'init-locales)
(require 'init-editing-utils)
(require 'init-whitespace)
(require 'init-isearch)
(require 'init-grep)
(require 'init-minibuffer)
(require 'init-corfu)
(when (and (require 'treesit nil t)
           (fboundp 'treesit-available-p)
           (treesit-available-p))
  (require 'init-treesitter))

(require 'init-local-themes)
(require-package 'meow)
(require 'init-local-meow)

(provide 'init-tui)
;;; init-tui.el ends here
